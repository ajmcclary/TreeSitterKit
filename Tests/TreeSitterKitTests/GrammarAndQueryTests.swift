import Foundation
import LanguageKit
import Testing
// This suite pins the raw standard registrations (grammar pointers + `.scm`
// query sources), which now live behind `@_spi(GrammarAuthoring)`. Ad-hoc
// query compilation and tree descriptions live in `TreeSitterDiagnostics`.
@_spi(GrammarAuthoring) import TreeSitterCore
@_spi(GrammarAuthoring) import TreeSitterStandardLanguages
import TreeSitterDiagnostics
import TreeSitterTestSupport

/// Every supported grammar loads and parses; every bundled query compiles.
@Suite struct GrammarAndQueryTests {
    @Test func standardRegistrationsCoverExactlyTheFourteenRepoPromptLanguages() throws {
        let registrations = try StandardSyntaxLanguages.registrations()
        let expected: Set<LanguageID> = [
            .swift, .javascript, .csharp, .python, .c, .rust, .cpp,
            .go, .java, .dart, .typescript, .tsx, .php, .ruby,
        ]
        #expect(Set(registrations.map(\.language)) == expected)
        #expect(registrations.count == 14)
        #expect(Set(StandardSyntaxLanguages.languages) == expected)
    }

    @Test(arguments: StandardSyntaxLanguages.languages)
    func grammarLoads(language: LanguageID) throws {
        let registrations = try StandardSyntaxLanguages.registrations()
        let registration = try #require(registrations.first { $0.language == language })
        #expect(registration.grammar() != nil, "\(language) grammar pointer should be non-nil")
    }

    @Test(arguments: StandardSyntaxLanguages.languages)
    func representativeSnippetParses(language: LanguageID) async throws {
        let parser = try SyntaxParser.standard()
        let snippet = try #require(SyntaxTestFixtures.snippet(for: language))
        let summary = try #require(try await parser.parseSummary(of: snippet, language: language))
        #expect(summary.hasRootNode)
        #expect(summary.language == language)
        let rootType = try #require(summary.rootNodeType)
        #expect(!rootType.isEmpty)
    }

    @Test(arguments: StandardSyntaxLanguages.languages)
    func minimalCharacterizationSnippetParses(language: LanguageID) async throws {
        let parser = try SyntaxParser.standard()
        let snippet = try #require(SyntaxTestFixtures.minimalSnippet(for: language))
        let description = try #require(try await parser.syntaxTreeDescription(of: snippet, language: language))
        #expect(!description.isEmpty)
    }

    @Test(arguments: StandardSyntaxLanguages.languages)
    func highlightQueryCompiles(language: LanguageID) async throws {
        let parser = try SyntaxParser.standard()
        let registrations = try StandardSyntaxLanguages.registrations()
        let registration = try #require(registrations.first { $0.language == language })
        let source = try #require(registration.highlightQuerySource, "\(language) should bundle a highlight query")
        try await parser.compileQuery(source, language: language)
    }

    @Test(arguments: StandardSyntaxLanguages.languages)
    func codeMapQueryCompiles(language: LanguageID) async throws {
        let parser = try SyntaxParser.standard()
        let registrations = try StandardSyntaxLanguages.registrations()
        let registration = try #require(registrations.first { $0.language == language })
        let source = try #require(registration.codeMapQuerySource, "\(language) should bundle a code-map query")
        try await parser.compileQuery(source, language: language)
    }

    @Test func typeScriptAndTSXShareQueryText() throws {
        let registrations = try StandardSyntaxLanguages.registrations()
        let ts = try #require(registrations.first { $0.language == .typescript })
        let tsx = try #require(registrations.first { $0.language == .tsx })
        // RepoPrompt oddity, deliberately preserved: .ts and .tsx are
        // registered against the same query strings; only the grammar differs.
        #expect(ts.highlightQuerySource == tsx.highlightQuerySource)
        #expect(ts.codeMapQuerySource == tsx.codeMapQuerySource)
    }
}
