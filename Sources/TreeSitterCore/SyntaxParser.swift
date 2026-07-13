import Foundation
import LanguageKit
import SwiftTreeSitter
import tree_sitter // for TSLanguage

/// An editor-neutral tree-sitter parsing engine.
///
/// `SyntaxParser` is the extraction of RepoPrompt's proven `SyntaxManager`:
/// it owns grammar wrappers and compiled queries, guards input size, and runs
/// highlight and code-map queries, returning only package-owned `Sendable`
/// value types (``SyntaxCapture``, ``SyntaxTreeSummary``, ``SyntaxQueryRun``).
/// No SwiftTreeSitter or grammar type appears in any public signature.
///
/// ## Serialization policy
///
/// Tree-sitter language wrappers, parsers, compiled queries, and especially
/// query cursors own C state; cursors are stateful and must never be shared
/// across threads. RepoPrompt serialized every tree-sitter entry point behind
/// a single recursive lock. Here the actor **is** that gate: all parsing and
/// query execution is actor-isolated, so operations run one at a time, and
/// every query cursor is created, consumed, and discarded within a single
/// isolated call. Concurrent callers are therefore safe and produce results
/// identical to serial execution.
///
/// ## Input-size policy
///
/// Content over ``SyntaxInputLimits`` thresholds is refused before any
/// tree-sitter work: ``captures(in:language:)`` and
/// ``codeMapCaptures(in:language:)`` return `[]`,
/// ``parseSummary(of:language:)`` returns `nil` (matching RepoPrompt's
/// behavior). Use ``oversizeReason(for:)`` to learn why content was refused.
public actor SyntaxParser {
    /// The input-size thresholds this parser enforces.
    public nonisolated let limits: SyntaxInputLimits

    private nonisolated let registrationsByLanguage: [LanguageID: SyntaxLanguageRegistration]

    // Grammar wrappers are created lazily and cached (RepoPrompt pre-warmed
    // at startup; laziness is behaviorally equivalent and avoids paying for
    // unused grammars).
    private var languageCache: [LanguageID: Language] = [:]

    // Compiled queries are cached per language, including failures, so a
    // broken query is compiled (and reported) once (RepoPrompt cached
    // highlight results the same way; its code-map store cached via static
    // initialization).
    private var highlightQueryCache: [LanguageID: Result<Query, SyntaxParserError>] = [:]
    private var codeMapQueryCache: [LanguageID: Result<Query, SyntaxParserError>] = [:]

    /// Creates a parser from language registrations.
    ///
    /// - Parameters:
    ///   - registrations: One registration per language. If multiple
    ///     registrations name the same language, the last one wins.
    ///   - limits: Input-size thresholds; defaults to RepoPrompt's shipping
    ///     values (``SyntaxInputLimits/standard``).
    public init(registrations: [SyntaxLanguageRegistration], limits: SyntaxInputLimits = .standard) {
        self.registrationsByLanguage = Dictionary(
            registrations.map { ($0.language, $0) },
            uniquingKeysWith: { _, last in last }
        )
        self.limits = limits
    }

    // MARK: - Language support (nonisolated, immutable after init)

    /// Every language this parser has a registration for.
    public nonisolated var supportedLanguages: Set<LanguageID> {
        Set(registrationsByLanguage.keys)
    }

    /// Whether the language has a registration in this parser.
    public nonisolated func isSupported(_ language: LanguageID) -> Bool {
        registrationsByLanguage[language] != nil
    }

    /// Whether the language is registered with a highlight query.
    public nonisolated func supportsHighlighting(_ language: LanguageID) -> Bool {
        registrationsByLanguage[language]?.highlightQuerySource != nil
    }

    /// Whether the language is registered with a code-map query. This is
    /// stricter than ``isSupported(_:)``, mirroring RepoPrompt's
    /// `supportsCodeMap(fileExtension:)`.
    public nonisolated func supportsCodeMap(_ language: LanguageID) -> Bool {
        registrationsByLanguage[language]?.codeMapQuerySource != nil
    }

    /// Whether consumers should use lightweight (raw declaration text)
    /// code-map extraction for this language (RepoPrompt's
    /// `isLightweight(language:)`).
    public nonisolated func usesLightweightCodeMapExtraction(_ language: LanguageID) -> Bool {
        registrationsByLanguage[language]?.usesLightweightCodeMapExtraction ?? false
    }

    /// Resolves a file extension to a **supported** language.
    ///
    /// Identity detection is LanguageKit's ``LanguageCatalog`` (case- and
    /// dot-insensitive); the result is non-`nil` only when the detected
    /// language is registered in this parser.
    public nonisolated func supportedLanguage(forFileExtension fileExtension: String) -> LanguageID? {
        guard let id = LanguageCatalog.language(forExtension: fileExtension)?.id else { return nil }
        return isSupported(id) ? id : nil
    }

    /// Returns a reason if the provided content should skip tree-sitter
    /// parsing, or `nil` when it is within all limits.
    public nonisolated func oversizeReason(for content: String) -> SyntaxOversizeReason? {
        limits.oversizeReason(for: content)
    }

    // MARK: - Parsing

    /// Parses content and returns a value-only summary.
    ///
    /// - Returns: The summary, or `nil` when the content is oversized or
    ///   parsing produced no root node (matching RepoPrompt's
    ///   `parseSummary`).
    /// - Throws: ``SyntaxParserError/unsupportedLanguage(_:)`` when the
    ///   language has no registration.
    public func parseSummary(of content: String, language: LanguageID) throws -> SyntaxTreeSummary? {
        let registration = try registration(for: language)
        if limits.oversizeReason(for: content) != nil {
            return nil
        }
        guard let grammar = try? grammarLanguage(for: registration) else { return nil }
        guard let tree = try parseTree(content: content, grammar: grammar),
              let root = tree.rootNode else {
            return nil
        }
        return SyntaxTreeSummary(
            language: language,
            rootNodeType: root.nodeType,
            hasRootNode: true
        )
    }

    /// Whether parsing the content produces a root node.
    public func parseSucceeds(_ content: String, language: LanguageID) throws -> Bool {
        try parseSummary(of: content, language: language)?.hasRootNode == true
    }

    // MARK: - Captures

    /// Runs the language's highlight query and returns its captures.
    ///
    /// Behavior (matching RepoPrompt's `highlight`):
    /// - Content over ``SyntaxInputLimits/highlightMaxLineCount`` lines, or
    ///   over the general parse limits, returns `[]`.
    /// - A language registered without a highlight query returns `[]`.
    /// - A highlight query that fails to compile throws, unless the
    ///   registration tolerates highlight failure, in which case `[]` is
    ///   returned. The compilation result (success or failure) is cached.
    ///
    /// - Throws: ``SyntaxParserError/unsupportedLanguage(_:)`` when the
    ///   language has no registration;
    ///   ``SyntaxParserError/queryCompilationFailed(language:kind:details:)``
    ///   on a non-tolerated compile failure.
    public func captures(in content: String, language: LanguageID) throws -> [SyntaxCapture] {
        let registration = try registration(for: language)

        // Fast, zero-allocation line guard (bails early once past the limit).
        guard SyntaxInputLimits.exceededLineCount(in: content.utf8, limit: limits.highlightMaxLineCount) == nil else {
            return []
        }
        if limits.oversizeReason(for: content) != nil {
            return []
        }

        guard let grammar = try? grammarLanguage(for: registration) else { return [] }

        let query: Query
        switch highlightQuery(for: registration, grammar: grammar) {
        case nil:
            return []
        case .success(let compiled)?:
            query = compiled
        case .failure(let error)?:
            if registration.toleratesHighlightQueryFailure {
                return []
            }
            throw error
        }

        guard let tree = try parseTree(content: content, grammar: grammar),
              let root = tree.rootNode else {
            return []
        }

        // Cursors are stateful: create per operation, consume within this
        // isolated call, never shared.
        let cursor = query.execute(node: root, in: tree)
        return cursor.highlights().map { SyntaxCapture(name: $0.name, range: $0.range) }
    }

    /// Runs the language's code-map query and returns its captures.
    ///
    /// Behavior (matching RepoPrompt's `codeMap`): oversized content returns
    /// `[]`; a missing or non-compiling code-map query throws.
    ///
    /// - Throws: ``SyntaxParserError/unsupportedLanguage(_:)``,
    ///   ``SyntaxParserError/missingQuery(_:_:)``, or
    ///   ``SyntaxParserError/queryCompilationFailed(language:kind:details:)``.
    public func codeMapCaptures(in content: String, language: LanguageID) throws -> [SyntaxCapture] {
        let registration = try registration(for: language)
        if limits.oversizeReason(for: content) != nil {
            return []
        }
        guard let grammar = try? grammarLanguage(for: registration) else { return [] }

        let query = try codeMapQuery(for: registration, grammar: grammar)

        guard let tree = try parseTree(content: content, grammar: grammar),
              let root = tree.rootNode else {
            return []
        }

        let cursor = query.execute(node: root, in: tree)
        return cursor.highlights().map { SyntaxCapture(name: $0.name, range: $0.range) }
    }

    // MARK: - Ad-hoc queries and tree inspection

    /// Compiles an ad-hoc query against the language's grammar, throwing on
    /// failure. Useful for validating query text in tests and tooling.
    public func compileQuery(_ querySource: String, language: LanguageID) throws {
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
    public func runQuery(_ querySource: String, on content: String, language: LanguageID) throws -> SyntaxQueryRun {
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
                    textPreview: Self.textPreview(for: capture.node.range, in: content)
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
    public func syntaxTreeDescription(of content: String, language: LanguageID) throws -> String? {
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
    public func nodeOutline(
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
            let preview = Self.textPreview(for: node.range, in: content)
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

    // MARK: - Internals

    private nonisolated func registration(for language: LanguageID) throws -> SyntaxLanguageRegistration {
        guard let registration = registrationsByLanguage[language] else {
            throw SyntaxParserError.unsupportedLanguage(language)
        }
        return registration
    }

    private func grammarLanguage(for registration: SyntaxLanguageRegistration) throws -> Language {
        if let cached = languageCache[registration.language] {
            return cached
        }
        guard let raw = registration.grammar() else {
            throw SyntaxParserError.grammarUnavailable(registration.language)
        }
        let language = Language(language: raw.assumingMemoryBound(to: TSLanguage.self))
        languageCache[registration.language] = language
        return language
    }

    private func parseTree(content: String, grammar: Language) throws -> MutableTree? {
        let parser = Parser()
        try parser.setLanguage(grammar)
        return parser.parse(content)
    }

    /// Cached highlight-query lookup. `nil` when the registration has no
    /// highlight query source.
    private func highlightQuery(
        for registration: SyntaxLanguageRegistration,
        grammar: Language
    ) -> Result<Query, SyntaxParserError>? {
        if let cached = highlightQueryCache[registration.language] {
            return cached
        }
        guard let source = registration.highlightQuerySource else { return nil }
        let result: Result<Query, SyntaxParserError>
        do {
            result = .success(try Query(language: grammar, data: Data(source.utf8)))
        } catch {
            result = .failure(SyntaxParserError.queryCompilationFailed(
                language: registration.language,
                kind: .highlights,
                details: String(describing: error)
            ))
        }
        highlightQueryCache[registration.language] = result
        return result
    }

    /// Cached code-map-query lookup; throws when missing or non-compiling.
    private func codeMapQuery(
        for registration: SyntaxLanguageRegistration,
        grammar: Language
    ) throws -> Query {
        if let cached = codeMapQueryCache[registration.language] {
            return try cached.get()
        }
        guard let source = registration.codeMapQuerySource else {
            throw SyntaxParserError.missingQuery(registration.language, .codeMap)
        }
        let result: Result<Query, SyntaxParserError>
        do {
            result = .success(try Query(language: grammar, data: Data(source.utf8)))
        } catch {
            result = .failure(SyntaxParserError.queryCompilationFailed(
                language: registration.language,
                kind: .codeMap,
                details: String(describing: error)
            ))
        }
        codeMapQueryCache[registration.language] = result
        return try result.get()
    }

    private static func textPreview(for range: NSRange, in content: String) -> String {
        guard let stringRange = Range(range, in: content) else { return "" }
        let raw = String(content[stringRange])
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        if raw.count <= 80 { return raw }
        return String(raw.prefix(80)) + "…"
    }
}
