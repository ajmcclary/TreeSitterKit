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
import TreeSitterDiagnostics

/// Verifies the product boundaries created by splitting TreeSitterKit into
/// stable (Core/StandardLanguages), authoring (GrammarAuthoring), and
/// diagnostic (Diagnostics) surfaces.
@Suite struct ModuleBoundaryTests {
    // MARK: - Grammar authoring is the public path to query sources

    @Test func grammarAuthoringExposesStandardQuerySources() throws {
        let sources = try GrammarAuthoring.standardLanguageQuerySources()
        #expect(sources.count == 14)
        for source in sources {
            #expect(source.highlightQuerySource?.isEmpty == false, "\(source.language) highlight source")
            #expect(source.codeMapQuerySource?.isEmpty == false, "\(source.language) code-map source")
        }
    }

    @Test func standardTypeScriptAndTSXShareQueryTextThroughAuthoringAPI() throws {
        let sources = try GrammarAuthoring.standardLanguageQuerySources()
        let ts = try #require(sources.first { $0.language == .typescript })
        let tsx = try #require(sources.first { $0.language == .tsx })
        // Same RepoPrompt oddity the characterization test pins, reached here
        // via the public authoring API rather than the raw registrations.
        #expect(ts.highlightQuerySource == tsx.highlightQuerySource)
        #expect(ts.codeMapQuerySource == tsx.codeMapQuerySource)
    }

    // MARK: - Grammar authoring is the public path to registration construction

    @Test func standardRegistrationsBuildACustomParser() throws {
        let registrations = try GrammarAuthoring.standardRegistrations()
        #expect(registrations.count == 14)
        let parser = SyntaxParser(registrations: registrations)
        #expect(parser.supportedLanguages.count == 14)
        #expect(parser.isSupported(.swift))
    }

    @Test func makeRegistrationIsPubliclyConstructible() throws {
        // The raw grammar-pointer initializer is SPI on the Core type; the
        // public constructor is `GrammarAuthoring.makeRegistration`.
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
