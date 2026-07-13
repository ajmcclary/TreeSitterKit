import Foundation
import LanguageKit
import Testing
// Deliberately uses ONLY the plain public imports (no `@_spi`): this suite is a
// compile-time proof that the grammar-authoring and diagnostics APIs live in —
// and are publicly reachable from — their dedicated products, while the stable
// `TreeSitterCore` / `TreeSitterStandardLanguages` surface stays clean.
import TreeSitterCore
import TreeSitterStandardLanguages
import TreeSitterGrammarAuthoring
import TreeSitterStandardLanguagesAuthoring
import TreeSitterDiagnostics

/// Verifies the product boundaries created by splitting TreeSitterKit into
/// stable (Core/StandardLanguages), custom-grammar authoring
/// (GrammarAuthoring), standard-languages authoring
/// (StandardLanguagesAuthoring), and diagnostic (Diagnostics) surfaces.
///
/// Manifest-level boundary pin (see `Package.swift`): the
/// `TreeSitterGrammarAuthoring` target depends on `TreeSitterCore` ALONE — it
/// does NOT depend on `TreeSitterStandardLanguages`, so importing it to build a
/// custom registration (below) resolves and links none of the 14 bundled
/// grammar targets. The standard-languages authoring accessors
/// (`standardLanguageQuerySources()` / `standardRegistrations()`) instead live
/// in `TreeSitterStandardLanguagesAuthoring`, which DOES link
/// `TreeSitterStandardLanguages`. `makeRegistrationIsPubliclyConstructible`
/// exercises only the grammars-free `GrammarAuthoring` module; the two
/// `StandardLanguagesAuthoring` tests exercise the grammar-linked one. A
/// true link-level negative test is not required — the split is enforced by the
/// manifest dependency claim above and this API split.
@Suite struct ModuleBoundaryTests {
    // MARK: - Standard-languages authoring is the public path to query sources

    @Test func standardLanguagesAuthoringExposesStandardQuerySources() throws {
        let sources = try StandardLanguagesAuthoring.standardLanguageQuerySources()
        #expect(sources.count == 14)
        for source in sources {
            #expect(source.highlightQuerySource?.isEmpty == false, "\(source.language) highlight source")
            #expect(source.codeMapQuerySource?.isEmpty == false, "\(source.language) code-map source")
        }
    }

    @Test func standardTypeScriptAndTSXShareQueryTextThroughAuthoringAPI() throws {
        let sources = try StandardLanguagesAuthoring.standardLanguageQuerySources()
        let ts = try #require(sources.first { $0.language == .typescript })
        let tsx = try #require(sources.first { $0.language == .tsx })
        // Same RepoPrompt oddity the characterization test pins, reached here
        // via the public authoring API rather than the raw registrations.
        #expect(ts.highlightQuerySource == tsx.highlightQuerySource)
        #expect(ts.codeMapQuerySource == tsx.codeMapQuerySource)
    }

    // MARK: - Standard-languages authoring is the public path to registration construction

    @Test func standardRegistrationsBuildACustomParser() throws {
        let registrations = try StandardLanguagesAuthoring.standardRegistrations()
        #expect(registrations.count == 14)
        let parser = SyntaxParser(registrations: registrations)
        #expect(parser.supportedLanguages.count == 14)
        #expect(parser.isSupported(.swift))
    }

    // MARK: - Grammar authoring is the (grammars-free) path to custom registrations

    @Test func makeRegistrationIsPubliclyConstructible() throws {
        // The raw grammar-pointer initializer is SPI on the Core type; the
        // public constructor is `GrammarAuthoring.makeRegistration`, from the
        // `TreeSitterGrammarAuthoring` product (TreeSitterCore only — no
        // standard grammars linked).
        let custom = LanguageID("madeuplang")
        let registration = GrammarAuthoring.makeRegistration(
            language: custom,
            grammar: { nil },
            highlightQuerySource: nil,
            codeMapQuerySource: nil
        )
        let parser = SyntaxParser(registrations: [registration])
        #expect(parser.isSupported(custom))
        #expect(!parser.supportsHighlighting(custom))
        #expect(!parser.supportsCodeMap(custom))
    }

    // MARK: - Diagnostics is the public path to ad-hoc queries / tree inspection

    @Test func diagnosticsAreReachableViaDiagnosticsModule() async throws {
        let parser = try SyntaxParser.standard()

        try await parser.compileQuery("(source_file) @root", language: .swift)

        let run = try await parser.runQuery(
            "(function_declaration (simple_identifier) @name)",
            on: "func greet() {}",
            language: .swift
        )
        #expect(run.matchCount == 1)
        #expect(run.captures.map(\.textPreview) == ["greet"])

        let description = try #require(try await parser.syntaxTreeDescription(of: "let x = 1", language: .swift))
        #expect(!description.isEmpty)

        let outline = try await parser.nodeOutline(of: "let x = 1", language: .swift)
        #expect(outline.contains("[source_file]"))
    }
}
