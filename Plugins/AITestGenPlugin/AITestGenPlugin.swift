import PackagePlugin
import Foundation

@main
struct AITestGenPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {

        let tool = try context.tool(named: "AITestGenTool")
        let projectPath = context.package.directory.string

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.path.string)
        process.arguments = ["--project", projectPath] + arguments

        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw PluginError.toolFailed(code: process.terminationStatus)
        }
    }
}

enum PluginError: Error, CustomStringConvertible {
    case toolFailed(code: Int32)

    var description: String {
        switch self {
        case .toolFailed(let code):
            return "AITestGenTool terminato con errore (codice \(code))"
        }
    }
}
