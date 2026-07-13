import Foundation
import LanguageKit
// The raw registration initializer is gated behind `@_spi(GrammarAuthoring)` in
// TreeSitterCore. This module reaches it through that SPI and re-exposes it as a
// small, deliberate *public* grammar-authoring API, so that plain
// `TreeSitterCore` importers never see raw grammar pointers.
//
// This module depends on TreeSitterCore ONLY — it does NOT link
// TreeSitterStandardLanguages or any bundled grammar. Custom-grammar authors
// import this product to build their own registrations without resolving the 14
// standard grammars. The standard languages' authoring accessors live in the
// separate `TreeSitterStandardLanguagesAuthoring` product.
@_spi(GrammarAuthoring) import TreeSitterCore

/// The public grammar-authoring surface for constructing custom-language
/// registrations.
///
/// Constructing a ``SyntaxLanguageRegistration`` (its raw grammar-pointer
/// closure and `.scm` query sources) is a *grammar-authoring* concern.
/// TreeSitterKit keeps it out of the stable `TreeSitterCore` product; this
/// module is the single public path to it. Because it depends only on
/// TreeSitterCore, importing it does not pull in the standard grammars.
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
}
