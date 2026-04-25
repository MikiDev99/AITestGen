import SwiftSyntax
import SwiftParser
import Foundation

// Rappresenta un metodo trovato nel codice
public struct ParsedMethod {
    public let name: String
    public let parameters: [(label: String, type: String)]
    public let returnType: String?
    public let isAsync: Bool
    public let isThrowing: Bool
    public let accessLevel: String
}

// Rappresenta una proprietà trovata nel codice
public struct ParsedProperty {
    public let name: String
    public let type: String
    public let isVar: Bool
}

// Rappresenta un tipo (struct, class, actor, enum) trovato nel file
public struct ParsedType {
    public let name: String
    public let keyword: String         // "struct", "class", "actor", "enum"
    public let protocols: [String]     // protocolli che implementa
    public let methods: [ParsedMethod]
    public let properties: [ParsedProperty]
}

// Il risultato dell'analisi di un intero file
public struct ParsedFile {
    public let url: URL
    public let types: [ParsedType]
    public let imports: [String]       // es: ["SwiftUI", "Foundation", "Combine"]

    // ── MODIFICA 1 ──────────────────────────────────────────────────────────
    // Aggiunto come stored property: viene popolato da TypeReferenceCollector
    public let allReferencedTypeNames: Set<String>

    // Retrocompatibile: DependencyIndex usa ancora .referencedTypeNames
    public var referencedTypeNames: Set<String> {
        allReferencedTypeNames
    }
    // ────────────────────────────────────────────────────────────────────────
}

// Il visitore che cammina sull'AST e raccoglie le informazioni
private class TypeCollector: SyntaxVisitor {
    var types: [ParsedType] = []
    var imports: [String] = []

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.path.map { $0.name.text }.joined(separator: ".")
        imports.append(name)
        return .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(parseMembers(
            name: node.name.text,
            keyword: "struct",
            inheritance: node.inheritanceClause,
            members: node.memberBlock.members
        ))
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(parseMembers(
            name: node.name.text,
            keyword: "class",
            inheritance: node.inheritanceClause,
            members: node.memberBlock.members
        ))
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(parseMembers(
            name: node.name.text,
            keyword: "actor",
            inheritance: node.inheritanceClause,
            members: node.memberBlock.members
        ))
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let protocols = node.inheritanceClause?.inheritedTypes
            .map { $0.type.trimmedDescription } ?? []
        types.append(ParsedType(
            name: node.name.text,
            keyword: "enum",
            protocols: protocols,
            methods: [],
            properties: []
        ))
        return .skipChildren
    }

    private func parseMembers(
        name: String,
        keyword: String,
        inheritance: InheritanceClauseSyntax?,
        members: MemberBlockItemListSyntax
    ) -> ParsedType {
        let protocols = inheritance?.inheritedTypes
            .map { $0.type.trimmedDescription } ?? []

        var methods: [ParsedMethod] = []
        var properties: [ParsedProperty] = []

        for member in members {
            if let fn = member.decl.as(FunctionDeclSyntax.self) {
                let access = fn.modifiers
                    .first { ["public", "internal", "private", "fileprivate", "open"].contains($0.name.text) }?
                    .name.text ?? "internal"

                guard access != "private", access != "fileprivate" else { continue }

                let params = fn.signature.parameterClause.parameters.map { p in
                    (
                        label: p.firstName.text == "_" ? (p.secondName?.text ?? "_") : p.firstName.text,
                        type: p.type.trimmedDescription
                    )
                }

                methods.append(ParsedMethod(
                    name: fn.name.text,
                    parameters: params,
                    returnType: fn.signature.returnClause?.type.trimmedDescription,
                    isAsync: fn.signature.effectSpecifiers?.asyncSpecifier != nil,
                    isThrowing: fn.signature.effectSpecifiers?.throwsClause != nil,
                    accessLevel: access
                ))
            }

            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                let isVar = varDecl.bindingSpecifier.text == "var"
                for binding in varDecl.bindings {
                    if let patternName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                       let typeAnnotation = binding.typeAnnotation?.type.trimmedDescription {
                        properties.append(ParsedProperty(
                            name: patternName,
                            type: typeAnnotation,
                            isVar: isVar
                        ))
                    }
                }
            }
        }

        return ParsedType(
            name: name,
            keyword: keyword,
            protocols: protocols,
            methods: methods,
            properties: properties
        )
    }
}

// ── MODIFICA 2 ──────────────────────────────────────────────────────────────
// Nuovo visitor: raccoglie tutti i nomi di tipo usati nell'intero file,
// incluse chiamate come UserProfile(...) e accessi come DirectoryData.items
private class TypeReferenceCollector: SyntaxVisitor {
    var referencedNames = Set<String>()

    // Cattura: DirectoryData.items, ModelProva.init(...)
    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if let base = node.base?.as(DeclReferenceExprSyntax.self) {
            referencedNames.insert(base.baseName.text)
        }
        return .visitChildren
    }

    // Cattura: UserProfile(...), SVGViewModel(), ModelProva()
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let decl = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            referencedNames.insert(decl.baseName.text)
        }
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self),
           let base = member.base?.as(DeclReferenceExprSyntax.self) {
            referencedNames.insert(base.baseName.text)
        }
        return .visitChildren
    }

    // Cattura type annotation esplicite: var x: SomeType, let y: OtherType?
    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        referencedNames.insert(node.name.text)
        return .visitChildren
    }
}
// ────────────────────────────────────────────────────────────────────────────

// L'entry point pubblico
public struct SwiftFileParser {
    public static func parse(file: SwiftSourceFile) throws -> ParsedFile {
        let source = try String(contentsOf: file.url, encoding: .utf8)
        let tree = Parser.parse(source: source)

        let collector = TypeCollector(viewMode: .sourceAccurate)
        collector.walk(tree)

        // ── MODIFICA 3 ────────────────────────────────────────────────────
        // Secondo walk con il nuovo collector
        let refCollector = TypeReferenceCollector(viewMode: .sourceAccurate)
        refCollector.walk(tree)
        // ──────────────────────────────────────────────────────────────────

        return ParsedFile(
            url: file.url,
            types: collector.types,
            imports: collector.imports,
            allReferencedTypeNames: refCollector.referencedNames  // ← MODIFICA 3
        )
    }
}
