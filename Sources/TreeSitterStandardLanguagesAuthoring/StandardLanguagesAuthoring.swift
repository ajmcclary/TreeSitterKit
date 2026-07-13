import Foundation
import LanguageKit
// The standard registrations' raw grammar pointers and `.scm` query sources are
// gated behind `@_spi(GrammarAuthoring)` in TreeSitterCore /
// TreeSitterStandardLanguages. This module reaches them through that SPI and
// re-exposes them as a small, deliberate *public* authoring API, so that plain
// `TreeSitterStandardLanguages` importers never see raw grammar pointers or
// `.scm` query text.
//
// Unlike `TreeSitterGrammarAuthoring` (custom-grammar construction, which links
// TreeSitterCore only), this module DOES link TreeSitterStandardLanguages and
// therefore resolves the 14 bundled grammars. Importing it is opt-in for
// consumers that specifically need the standard languages' authoring surface.
@_spi(GrammarAuthoring) import TreeSitterCore
@_spi(GrammarAuthoring) import TreeSitterStandardLanguages

/// The bundled highlight and code-map query source (`.scm`) text for one
/// standard language.
///
/// This is the *public* path to the standard languages' query sources: plain
/// `TreeSitterStandardLanguages` importers get a configured parser and
/// capability metadata, not query text. Import
/// `TreeSitterStandardLanguagesAuthoring` (this module) to read the raw query
/// sources — e.g. to render, edit, or re-run them in a query-development tool.
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

/// The public authoring surface for the 14 standard languages.
///
/// Reading the standard languages' raw registrations and bundled `.scm` query
/// sources is a *grammar-authoring* concern. TreeSitterKit keeps it out of the
/// stable `TreeSitterCore` / `TreeSitterStandardLanguages` products; this module
/// is the single public path to it. Because it links
/// `TreeSitterStandardLanguages`, importing it resolves the bundled grammars —
/// custom-grammar authors who only need ``GrammarAuthoring/makeRegistration``
/// should import `TreeSitterGrammarAuthoring` instead, which does not.
public enum StandardLanguagesAuthoring {
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
