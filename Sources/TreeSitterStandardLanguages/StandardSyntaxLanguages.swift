import Foundation
import LanguageKit
// `@_spi(GrammarAuthoring)` is required to construct `SyntaxLanguageRegistration`
// values (the raw grammar-pointer initializer is gated behind that SPI). This
// keeps registration construction out of the stable `TreeSitterCore` surface
// while letting this target — and the `TreeSitterGrammarAuthoring` product —
// assemble the standard registrations.
@_spi(GrammarAuthoring) import TreeSitterCore

import TreeSitterC
import TreeSitterCPP
import TreeSitterCSharp
import TreeSitterDart
import TreeSitterGo
import TreeSitterJava
import TreeSitterJavaScript
import TreeSitterPHP
import TreeSitterPython
import TreeSitterRuby
import TreeSitterRust
import TreeSitterSwift
import TreeSitterTSX
import TreeSitterTypeScript

/// Errors thrown while assembling the standard language registrations.
public enum StandardSyntaxLanguagesError: Error, Hashable, Sendable, LocalizedError {
    /// A bundled query resource could not be located.
    case missingQueryResource(language: LanguageID, kind: SyntaxQueryKind)
    /// A bundled query resource could not be decoded as UTF-8.
    case unreadableQueryResource(language: LanguageID, kind: SyntaxQueryKind)

    public var errorDescription: String? {
        switch self {
        case .missingQueryResource(let language, let kind):
            return "Missing bundled \(kind.rawValue) query resource for \(language.rawValue)"
        case .unreadableQueryResource(let language, let kind):
            return "Bundled \(kind.rawValue) query resource for \(language.rawValue) is not valid UTF-8"
        }
    }
}

/// The 14 languages RepoPrompt's `SyntaxManager` shipped with, registered
/// with the same grammars (identical dependency pins) and byte-identical
/// query text, now bundled as SwiftPM resources of this target.
public enum StandardSyntaxLanguages {
    /// The supported languages, in RepoPrompt's `LanguageType` declaration
    /// order (spelled as LanguageKit ids: `js` -> `javascript`,
    /// `ts` -> `typescript`, `c_sharp` -> `csharp`).
    public static let languages: [LanguageID] = [
        .swift, .javascript, .csharp, .python, .c, .rust, .cpp,
        .go, .java, .dart, .typescript, .tsx, .php, .ruby,
    ]

    /// Builds the standard registrations, loading each language's highlight
    /// and code-map query text from this target's bundled resources.
    ///
    /// - Throws: ``StandardSyntaxLanguagesError`` when a bundled query
    ///   resource is missing or unreadable (indicates a corrupted install;
    ///   cannot happen in an intact package checkout).
    ///
    /// Gated behind `@_spi(GrammarAuthoring)`: these registrations carry raw
    /// grammar pointers and `.scm` query source text, which are grammar-
    /// authoring surface, not part of the stable parsing API. Regular
    /// consumers build a parser via ``SyntaxParser/standard(limits:)``; the
    /// `TreeSitterGrammarAuthoring` product re-exposes this (and the query
    /// sources) publicly.
    @_spi(GrammarAuthoring)
    public static func registrations() throws -> [SyntaxLanguageRegistration] {
        // RepoPrompt behavior notes, preserved here:
        // - TypeScript and TSX share the same highlight and code-map query
        //   text (both load from the "typescript" resource folder); only the
        //   grammar differs.
        // - PHP and Ruby tolerate highlight-query compile failures (degrade
        //   to no highlights instead of throwing).
        // - PHP, Ruby, JavaScript, TypeScript, and TSX use "lightweight"
        //   code-map extraction (RepoPrompt's `isLightweight(language:)`).
        return [
            try registration(.swift, folder: "swift") { tree_sitter_swift().map(UnsafeRawPointer.init) },
            try registration(
                .javascript, folder: "javascript",
                usesLightweightCodeMapExtraction: true
            ) { tree_sitter_javascript().map(UnsafeRawPointer.init) },
            try registration(.csharp, folder: "csharp") { tree_sitter_c_sharp().map(UnsafeRawPointer.init) },
            try registration(.python, folder: "python") { tree_sitter_python().map(UnsafeRawPointer.init) },
            try registration(.c, folder: "c") { tree_sitter_c().map(UnsafeRawPointer.init) },
            try registration(.rust, folder: "rust") { tree_sitter_rust().map(UnsafeRawPointer.init) },
            try registration(.cpp, folder: "cpp") { tree_sitter_cpp().map(UnsafeRawPointer.init) },
            try registration(.go, folder: "go") { tree_sitter_go().map(UnsafeRawPointer.init) },
            try registration(.java, folder: "java") { tree_sitter_java().map(UnsafeRawPointer.init) },
            try registration(.dart, folder: "dart") { tree_sitter_dart().map(UnsafeRawPointer.init) },
            try registration(
                .typescript, folder: "typescript",
                usesLightweightCodeMapExtraction: true
            ) { tree_sitter_typescript().map(UnsafeRawPointer.init) },
            try registration(
                .tsx, folder: "typescript",
                usesLightweightCodeMapExtraction: true
            ) { tree_sitter_tsx().map(UnsafeRawPointer.init) },
            try registration(
                .php, folder: "php",
                toleratesHighlightQueryFailure: true,
                usesLightweightCodeMapExtraction: true
            ) { tree_sitter_php().map(UnsafeRawPointer.init) },
            try registration(
                .ruby, folder: "ruby",
                toleratesHighlightQueryFailure: true,
                usesLightweightCodeMapExtraction: true
            ) { tree_sitter_ruby().map(UnsafeRawPointer.init) },
        ]
    }

    // MARK: - Internals

    private static func registration(
        _ language: LanguageID,
        folder: String,
        toleratesHighlightQueryFailure: Bool = false,
        usesLightweightCodeMapExtraction: Bool = false,
        grammar: @escaping @Sendable () -> UnsafeRawPointer?
    ) throws -> SyntaxLanguageRegistration {
        SyntaxLanguageRegistration(
            language: language,
            grammar: grammar,
            highlightQuerySource: try querySource(language: language, folder: folder, kind: .highlights),
            codeMapQuerySource: try querySource(language: language, folder: folder, kind: .codeMap),
            toleratesHighlightQueryFailure: toleratesHighlightQueryFailure,
            usesLightweightCodeMapExtraction: usesLightweightCodeMapExtraction
        )
    }

    private static func querySource(
        language: LanguageID,
        folder: String,
        kind: SyntaxQueryKind
    ) throws -> String {
        let resourceName: String
        switch kind {
        case .highlights: resourceName = "highlights"
        case .codeMap: resourceName = "codemap"
        case .adHoc:
            throw StandardSyntaxLanguagesError.missingQueryResource(language: language, kind: kind)
        }
        guard let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "scm",
            subdirectory: "Queries/\(folder)"
        ) else {
            throw StandardSyntaxLanguagesError.missingQueryResource(language: language, kind: kind)
        }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw StandardSyntaxLanguagesError.unreadableQueryResource(language: language, kind: kind)
        }
        return text
    }
}

public extension SyntaxParser {
    /// A parser preloaded with the 14 standard language registrations.
    ///
    /// - Parameter limits: Input-size thresholds; defaults to
    ///   ``SyntaxInputLimits/standard``.
    /// - Throws: ``StandardSyntaxLanguagesError`` when a bundled query
    ///   resource is missing or unreadable.
    static func standard(limits: SyntaxInputLimits = .standard) throws -> SyntaxParser {
        SyntaxParser(registrations: try StandardSyntaxLanguages.registrations(), limits: limits)
    }
}
