import Foundation
import LanguageKit
import SwiftTreeSitter
// Diagnostics reaches `SyntaxParser`'s grammar/parse-tree primitives through
// the `@_spi(Diagnostics)` surface exposed by TreeSitterCore. Those primitives
// return SwiftTreeSitter values, so this module imports SwiftTreeSitter — but
// only these ad-hoc-query and tree-inspection APIs live here, and none of them
// expose a SwiftTreeSitter type in their public signatures.
@_spi(Diagnostics) import TreeSitterCore

/// Ad-hoc query compilation, ad-hoc query execution, and parse-tree inspection
/// for ``SyntaxParser``.
///
/// These are grammar-development and debugging tools (RepoPrompt's
/// `debugCompileQuery` / `debugRunQuery` / `debugTreeDescription` /
/// `debugNodeOutline`). They are deliberately kept out of `TreeSitterCore`'s
/// stable surface: importing only `TreeSitterCore` (and
/// `TreeSitterStandardLanguages`) gives you parsing, captures, summaries,
/// capabilities, limits, and errors — but not this debug API. Import
/// `TreeSitterDiagnostics` to opt in.
public extension SyntaxParser {
    /// Compiles an ad-hoc query against the language's grammar, throwing on
    /// failure. Useful for validating query text in tests and tooling.
    ///
    /// - Throws: ``SyntaxParserError/unsupportedLanguage(_:)`` when the
    ///   language has no registration;
    ///   ``SyntaxParserError/queryCompilationFailed(language:kind:details:)``
    ///   (with ``SyntaxQueryKind/adHoc``) when the query does not compile.
    func compileQuery(_ querySource: String, language: LanguageID) throws {
        let registration = try registration(for: language)
        let grammar = try grammarLanguage(for: registration)
        do {
            _ = try Query(language: grammar, data: Data(querySource.utf8))
        } catch {
            throw SyntaxParserError.queryCompilationFailed(
                language: language,
                kind: .adHoc,
                details: String(describing: error)
            )
        }
    }

    /// Parses content and runs an ad-hoc query, returning all matches'
    /// captures with text previews (RepoPrompt's `debugRunQuery`).
    func runQuery(_ querySource: String, on content: String, language: LanguageID) throws -> SyntaxQueryRun {
        let registration = try registration(for: language)
        let grammar = try grammarLanguage(for: registration)
        guard let tree = try parseTree(content: content, grammar: grammar),
              let root = tree.rootNode else {
            throw SyntaxParserError.parseFailed(language)
        }

        let query: Query
        do {
            query = try Query(language: grammar, data: Data(querySource.utf8))
        } catch {
            throw SyntaxParserError.queryCompilationFailed(
                language: language,
                kind: .adHoc,
                details: String(describing: error)
            )
        }

        let cursor = query.execute(node: root, in: tree)
        var captures: [SyntaxQueryRunCapture] = []
        var matchCount = 0
        while let match = cursor.next() {
            matchCount += 1
            for capture in match.captures {
                let captureName = query.captureName(for: capture.index) ?? "unknown"
                captures.append(SyntaxQueryRunCapture(
                    name: captureName,
                    range: capture.node.range,
                    textPreview: Self.diagnosticTextPreview(for: capture.node.range, in: content)
                ))
            }
        }
        return SyntaxQueryRun(
            rootNodeType: root.nodeType,
            captures: captures,
            matchCount: matchCount
        )
    }

    /// The parse tree's S-expression description (RepoPrompt's
    /// `debugTreeDescription`).
    func syntaxTreeDescription(of content: String, language: LanguageID) throws -> String? {
        let registration = try registration(for: language)
        let grammar = try grammarLanguage(for: registration)
        guard let tree = try parseTree(content: content, grammar: grammar),
              let root = tree.rootNode else {
            throw SyntaxParserError.parseFailed(language)
        }
        return root.sExpressionString ?? root.debugDescription
    }

    /// An indented outline of the parse tree's nodes with text previews
    /// (RepoPrompt's `debugNodeOutline`).
    func nodeOutline(
        of content: String,
        language: LanguageID,
        maxDepth: Int = 6,
        maxNodes: Int = 250
    ) throws -> String {
        let registration = try registration(for: language)
        let grammar = try grammarLanguage(for: registration)
        guard let tree = try parseTree(content: content, grammar: grammar),
              let root = tree.rootNode else {
            throw SyntaxParserError.parseFailed(language)
        }

        var lines: [String] = []
        var visited = 0
        func visit(_ node: Node, depth: Int) {
            guard visited < maxNodes else { return }
            visited += 1
            let indent = String(repeating: "  ", count: depth)
            let nodeType = node.nodeType ?? "unknown"
            let preview = Self.diagnosticTextPreview(for: node.range, in: content)
            lines.append("\(indent)[\(nodeType)] '\(preview)'")
            guard depth < maxDepth else { return }
            for index in 0..<node.childCount {
                guard let child = node.child(at: index) else { continue }
                visit(child, depth: depth + 1)
            }
        }
        visit(root, depth: 0)
        if visited >= maxNodes {
            lines.append("… truncated after \(maxNodes) nodes")
        }
        return lines.joined(separator: "\n")
    }

    /// Newline/tab-escaped, 80-character-truncated preview of the source text
    /// in `range` (shared by ``runQuery(_:on:language:)`` and
    /// ``nodeOutline(of:language:maxDepth:maxNodes:)``).
    private static func diagnosticTextPreview(for range: NSRange, in content: String) -> String {
        guard let stringRange = Range(range, in: content) else { return "" }
        let raw = String(content[stringRange])
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        if raw.count <= 80 { return raw }
        return String(raw.prefix(80)) + "…"
    }
}
