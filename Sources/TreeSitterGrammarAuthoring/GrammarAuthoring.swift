import Foundation
import LanguageKit
// The raw registration initializer and the standard registrations' query
// sources are gated behind `@_spi(GrammarAuthoring)` in TreeSitterCore /
// TreeSitterStandardLanguages. This module reaches them through that SPI and
// re-exposes them as a small, deliberate *public* grammar-authoring API, so
// that plain `TreeSitterCore` / `TreeSitterStandardLanguages` importers never
// see raw grammar pointers or `.scm` query text.
@_spi(GrammarAuthoring) import TreeSitterCore
@_spi(GrammarAuthoring) import TreeSitterStandardLanguages

/// The bundled highlight and code-map query source (`.scm`) text for one
/// standard language.
///
/// This is the *public* path to the standard languages' query sources: plain
/// `TreeSitterStandardLanguages` importers get a configured parser and
/// capability metadata, not query text. Import `TreeSitterGrammarAuthoring`
/// (this module) to read the raw query sources — e.g. to render, edit, or
/// re-run them in a query-development tool.
public struct StandardLanguageQuerySource: Hashable, Sendable {
    /// The language identity these query sources serve.
    public let language: LanguageID

    /// Highlight query (`.scm`) text, or `nil` when the language bundles none.
    public let highlightQuerySource: String?

    /// Code-map query (`.scm`) text, or `nil` when the language bundles none.
    public let codeMapQuerySource: String?

    /// Creates a query-source value.
    public init(language: LanguageID, highlightQuerySource: String?, codeMapQuerySource: String?) {
        self.language = language
        self.highlightQuerySource = highlightQuerySource
        self.codeMapQuerySource = codeMapQuerySource
    }
}

/// The public grammar-authoring surface for TreeSitterKit.
///
/// Constructing a ``SyntaxLanguageRegistration`` (its raw grammar-pointer
/// closure and `.scm` query sources) and reading the standard languages' query
/// sources are *grammar-authoring* concerns. TreeSitterKit keeps them out of
/// the stable `TreeSitterCore` / `TreeSitterStandardLanguages` products; this
/// module is the single public path to them.
public enum GrammarAuthoring {
    /// Builds a custom-language registration from a raw grammar-pointer closure
    /// and optional query sources.
    ///
    /// The `grammar` closure returns the generated `tree_sitter_<lang>()`
    /// pointer erased to `UnsafeRawPointer` (e.g.
    /// `{ tree_sitter_mylang().map(UnsafeRawPointer.init) }`). Pass the result,
    /// with any others, to ``SyntaxParser/init(registrations:limits:)``.
    ///
    /// - Parameters:
    ///   - language: The language identity this registration serves.
    ///   - grammar: Closure returning the grammar's `const TSLanguage *` erased
    ///     to `UnsafeRawPointer`.
    ///   - highlightQuerySource: Highlight query text, or `nil`.
    ///   - codeMapQuerySource: Code-map query text, or `nil`.
    ///   - toleratesHighlightQueryFailure: Whether highlight-query compile
    ///     failures degrade to an empty result instead of throwing.
    ///   - usesLightweightCodeMapExtraction: Whether consumers should use
    ///     lightweight (raw-text) code-map extraction for this language.
    public static func makeRegistration(
        language: LanguageID,
        grammar: @escaping @Sendable () -> UnsafeRawPointer?,
        highlightQuerySource: String?,
        codeMapQuerySource: String?,
        toleratesHighlightQueryFailure: Bool = false,
        usesLightweightCodeMapExtraction: Bool = false
    ) -> SyntaxLanguageRegistration {
        SyntaxLanguageRegistration(
            language: language,
            grammar: grammar,
            highlightQuerySource: highlightQuerySource,
            codeMapQuerySource: codeMapQuerySource,
            toleratesHighlightQueryFailure: toleratesHighlightQueryFailure,
            usesLightweightCodeMapExtraction: usesLightweightCodeMapExtraction
        )
    }

    /// The 14 standard-language registrations, with their raw grammar pointers
    /// and bundled query sources.
    ///
    /// Most consumers should prefer ``SyntaxParser/standard(limits:)`` — this
    /// returns the raw registrations for callers assembling a custom parser
    /// (e.g. combining the standard languages with additional custom ones).
    ///
    /// - Throws: the standard-languages bundle error when a query resource is
    ///   missing or unreadable.
    public static func standardRegistrations() throws -> [SyntaxLanguageRegistration] {
        try StandardSyntaxLanguages.registrations()
    }

    /// The bundled highlight and code-map query sources for every standard
    /// language, in the standard-language declaration order.
    ///
    /// - Throws: the standard-languages bundle error when a query resource is
    ///   missing or unreadable.
    public static func standardLanguageQuerySources() throws -> [StandardLanguageQuerySource] {
        try StandardSyntaxLanguages.registrations().map {
            StandardLanguageQuerySource(
                language: $0.language,
                highlightQuerySource: $0.highlightQuerySource,
                codeMapQuerySource: $0.codeMapQuerySource
            )
        }
    }
}
