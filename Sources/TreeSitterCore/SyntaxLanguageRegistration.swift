import Foundation
import LanguageKit

/// Everything a ``SyntaxParser`` needs to support one language: its identity,
/// a way to obtain the compiled tree-sitter grammar, and its query sources.
///
/// The grammar is supplied as a closure returning the grammar's
/// `const TSLanguage *` erased to `UnsafeRawPointer`, so that no
/// tree-sitter or SwiftTreeSitter type appears in any public signature.
/// Grammar pointers produced by generated `tree_sitter_<id>()` functions are
/// pointers to immutable static data and are safe to share across threads.
public struct SyntaxLanguageRegistration: Sendable {
    /// The language identity (from LanguageKit) this registration serves.
    public let language: LanguageID

    /// Returns the grammar's `const TSLanguage *` erased to a raw pointer,
    /// or `nil` when the grammar is unavailable.
    public let grammar: @Sendable () -> UnsafeRawPointer?

    /// Query source (`.scm` text) used for highlighting, or `nil` when the
    /// language has no highlight query.
    public let highlightQuerySource: String?

    /// Query source (`.scm` text) used for code-map extraction, or `nil`
    /// when the language has no code-map query.
    public let codeMapQuerySource: String?

    /// When `true`, a highlight-query compilation failure yields an empty
    /// highlight result instead of throwing (RepoPrompt tolerated this for
    /// PHP and Ruby).
    public let toleratesHighlightQueryFailure: Bool

    /// Whether this language's code-map extraction is "lightweight" -- the
    /// consumer relies on raw declaration text rather than full type parsing
    /// (RepoPrompt: PHP, Ruby, JavaScript, TypeScript, TSX).
    public let usesLightweightCodeMapExtraction: Bool

    /// Creates a registration.
    ///
    /// - Parameters:
    ///   - language: The language identity this registration serves.
    ///   - grammar: Closure returning the grammar's `const TSLanguage *`
    ///     erased to `UnsafeRawPointer` (e.g.
    ///     `{ tree_sitter_swift().map(UnsafeRawPointer.init) }`).
    ///   - highlightQuerySource: Highlight query text, or `nil`.
    ///   - codeMapQuerySource: Code-map query text, or `nil`.
    ///   - toleratesHighlightQueryFailure: Whether highlight-query compile
    ///     failures degrade to an empty result instead of throwing.
    ///   - usesLightweightCodeMapExtraction: Whether consumers should use
    ///     lightweight (raw-text) code-map extraction for this language.
    public init(
        language: LanguageID,
        grammar: @escaping @Sendable () -> UnsafeRawPointer?,
        highlightQuerySource: String?,
        codeMapQuerySource: String?,
        toleratesHighlightQueryFailure: Bool = false,
        usesLightweightCodeMapExtraction: Bool = false
    ) {
        self.language = language
        self.grammar = grammar
        self.highlightQuerySource = highlightQuerySource
        self.codeMapQuerySource = codeMapQuerySource
        self.toleratesHighlightQueryFailure = toleratesHighlightQueryFailure
        self.usesLightweightCodeMapExtraction = usesLightweightCodeMapExtraction
    }
}
