import Foundation
import LanguageKit

/// The kind of query a ``SyntaxParser`` runs.
public enum SyntaxQueryKind: String, Hashable, Sendable, CaseIterable {
    /// Highlighting query (RepoPrompt's "optimized" highlight queries).
    case highlights
    /// Code-map / structure-extraction query.
    case codeMap
    /// An ad-hoc query supplied by the caller (see
    /// ``SyntaxParser/runQuery(_:on:language:)`` and
    /// ``SyntaxParser/compileQuery(_:language:)``).
    case adHoc
}

/// Typed errors thrown by ``SyntaxParser``.
public enum SyntaxParserError: Error, Hashable, Sendable {
    /// The language has no registration in this parser.
    case unsupportedLanguage(LanguageID)

    /// The language is registered but its grammar function returned no
    /// language pointer.
    case grammarUnavailable(LanguageID)

    /// The language is registered but carries no query of the requested kind.
    case missingQuery(LanguageID, SyntaxQueryKind)

    /// A query failed to compile against the language's grammar.
    case queryCompilationFailed(language: LanguageID, kind: SyntaxQueryKind, details: String)

    /// Parsing produced no tree or no root node.
    case parseFailed(LanguageID)
}

extension SyntaxParserError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language.rawValue)"
        case .grammarUnavailable(let language):
            return "No tree-sitter grammar pointer available for language: \(language.rawValue)"
        case .missingQuery(let language, let kind):
            return "Missing \(kind.rawValue) query for language: \(language.rawValue)"
        case .queryCompilationFailed(let language, let kind, let details):
            return "Failed to compile \(kind.rawValue) query for \(language.rawValue): \(details)"
        case .parseFailed(let language):
            return "Parse produced no root node for language: \(language.rawValue)"
        }
    }
}
