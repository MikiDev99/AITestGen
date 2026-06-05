import Foundation

public struct CrashFrame {
    public let index: Int
    public let module: String
    public let method: String
    public let fileName: String?
    public let lineNumber: Int?
}

public struct CrashedThread {
    public let name: String
    public let frames: [CrashFrame]

    // Solo i frame rilevanti — esclude sistema e framework noti
    public var relevantFrames: [CrashFrame] {
        frames.filter { !CrashLogParser.isSystemModule($0.module) }
    }

    // File sorgente dell'app coinvolti nel crash
    public var sourceFiles: [String] {
        relevantFrames
            .compactMap { $0.fileName }
            .filter { $0.hasSuffix(".swift") }
            .reduce(into: [String]()) { result, file in
                if !result.contains(file) { result.append(file) }
            }
    }
}

public struct ParsedCrashLog {
    public let appName: String?
    public let crashedThread: CrashedThread?
    public let allThreads: [CrashedThread]
    public let rawContent: String

    // Riassunto testuale da passare al LLM
    public var summary: String {
        guard let thread = crashedThread else {
            return "No crashed thread identified.\n\nRaw log:\n\(rawContent)"
        }

        var lines: [String] = []
        lines.append("Crashed thread: \(thread.name)")
        lines.append("")
        lines.append("Relevant frames:")
        for frame in thread.relevantFrames {
            var line = "  \(frame.index). [\(frame.module)] \(frame.method)"
            if let file = frame.fileName, let lineNum = frame.lineNumber {
                line += " (\(file):\(lineNum))"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}

public struct CrashLogParser {

    // Moduli di sistema da escludere
    static let systemModulePrefixes = [
        "libsystem_", "libswift", "libdispatch", "libswiftDispatch",
        "CoreFoundation", "Foundation", "UIKitCore", "UIKit",
        "Combine", "FirebaseCrashlytics", "CFNetwork",
        "JavaScriptCore", "WebKit", "GraphicsServices",
        "libsystem_pthread", "libsystem_kernel", "Logger",
        "libpas", "DI_Framework"
    ]

    public static func isSystemModule(_ module: String) -> Bool {
        systemModulePrefixes.contains { module.hasPrefix($0) }
    }

    public static func parse(fileURL: URL) throws -> ParsedCrashLog {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return parse(content: content)
    }

    public static func parse(content: String) -> ParsedCrashLog {
        let lines = content.components(separatedBy: "\n")

        // Estrae il nome dell'app dal bundle id se presente
        let appName = extractAppName(from: lines)

        // Separa i thread
        let threads = extractThreads(from: lines)

        // Identifica il thread crashato
        let crashedThread = threads.first { $0.name.contains("Crashed") }
            ?? findMostRelevantThread(from: threads)

        return ParsedCrashLog(
            appName: appName,
            crashedThread: crashedThread,
            allThreads: threads,
            rawContent: content
        )
    }

    // MARK: - Private

    private static func extractAppName(from lines: [String]) -> String? {
        for line in lines {
            if line.hasPrefix("# Application:") {
                return line
                    .replacingOccurrences(of: "# Application:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func extractThreads(from lines: [String]) -> [CrashedThread] {
        var threads: [CrashedThread] = []
        var currentThreadName: String? = nil
        var currentFrames: [CrashFrame] = []

        // Pattern per riconoscere l'inizio di un thread
        // es: "Crashed: WEBSOCKET_THREAD" o "com.apple.main-thread"
        let threadHeaderPattern = try? NSRegularExpression(
            pattern: #"^(Crashed:\s*.+|com\..+|Thread\s*\(.+\)|[\w.]+thread[\w.]*)$"#,
            options: .caseInsensitive
        )

        // Pattern per i frame
        // es: "0  LibName   0x1234  methodName + offset"
        let framePattern = try? NSRegularExpression(
            pattern: #"^\s*(\d+)\s+(\S+)\s+0x[0-9a-fA-F]+\s+(.+?)(?:\s+\+\s+\d+)?(?:\s+\((.+?):(\d+)\))?$"#
        )

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Controlla se è intestazione di thread
            if let pattern = threadHeaderPattern,
               pattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil,
               !trimmed.hasPrefix("#"),
               !trimmed.isEmpty {

                // Salva il thread precedente
                if let name = currentThreadName, !currentFrames.isEmpty {
                    threads.append(CrashedThread(name: name, frames: currentFrames))
                }

                currentThreadName = trimmed
                currentFrames = []
                continue
            }

            // Controlla se è un frame
            if let pattern = framePattern,
               let match = pattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {

                let indexStr = substring(trimmed, match: match, group: 1)
                let module = substring(trimmed, match: match, group: 2)
                let method = substring(trimmed, match: match, group: 3)?.trimmingCharacters(in: .whitespaces)
                let fileName = substring(trimmed, match: match, group: 4)
                let lineStr = substring(trimmed, match: match, group: 5)

                currentFrames.append(CrashFrame(
                    index: Int(indexStr ?? "0") ?? 0,
                    module: module ?? "Unknown",
                    method: method ?? "Unknown",
                    fileName: fileName,
                    lineNumber: lineStr.flatMap { Int($0) }
                ))
            }
        }

        // Salva l'ultimo thread
        if let name = currentThreadName, !currentFrames.isEmpty {
            threads.append(CrashedThread(name: name, frames: currentFrames))
        }

        return threads
    }

    // Se non c'è un thread esplicitamente crashato, prende quello
    // con più frame rilevanti dell'app
    private static func findMostRelevantThread(from threads: [CrashedThread]) -> CrashedThread? {
        threads.max { a, b in
            a.relevantFrames.count < b.relevantFrames.count
        }
    }

    private static func substring(
        _ string: String,
        match: NSTextCheckingResult,
        group: Int
    ) -> String? {
        guard group < match.numberOfRanges else { return nil }
        let range = match.range(at: group)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: string) else { return nil }
        return String(string[swiftRange])
    }
}
