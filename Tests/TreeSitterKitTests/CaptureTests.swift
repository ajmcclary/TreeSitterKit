import Foundation
import LanguageKit
import Testing
import TreeSitterCore
import TreeSitterStandardLanguages
import TreeSitterTestSupport

/// Representative snippets produce non-empty highlight and code-map captures
/// per language, with ranges that are valid UTF-16 ranges of the source.
@Suite struct CaptureTests {
    @Test(arguments: StandardSyntaxLanguages.languages)
    func highlightCapturesAreNonEmpty(language: LanguageID) async throws {
        let parser = try SyntaxParser.standard()
        let snippet = try #require(SyntaxTestFixtures.snippet(for: language))
        let captures = try await parser.captures(in: snippet, language: language)
        #expect(!captures.isEmpty, "\(language) highlight captures should be non-empty")
        for capture in captures {
            #expect(!capture.name.isEmpty)
            #expect(
                Range(capture.range, in: snippet) != nil,
                "\(language) capture \(capture.name) range \(capture.range) should be a valid UTF-16 range"
            )
        }
    }

    @Test(arguments: StandardSyntaxLanguages.languages)
    func codeMapCapturesAreNonEmpty(language: LanguageID) async throws {
        let parser = try SyntaxParser.standard()
        let snippet = try #require(SyntaxTestFixtures.snippet(for: language))
        let captures = try await parser.codeMapCaptures(in: snippet, language: language)
        #expect(!captures.isEmpty, "\(language) code-map captures should be non-empty")
        for capture in captures {
            #expect(!capture.name.isEmpty)
            #expect(Range(capture.range, in: snippet) != nil)
        }
    }

    @Test func runQueryReportsMatchesAndPreviews() async throws {
        let parser = try SyntaxParser.standard()
        let content = "func greet() {}\nfunc other() {}"
        let run = try await parser.runQuery(
            "(function_declaration (simple_identifier) @name)",
            on: content,
            language: .swift
        )
        #expect(run.matchCount == 2)
        #expect(run.captures.map(\.textPreview).sorted() == ["greet", "other"])
        #expect(run.rootNodeType == "source_file")
    }

    @Test func nodeOutlineListsRootAndChildren() async throws {
        let parser = try SyntaxParser.standard()
        let outline = try await parser.nodeOutline(of: "let x = 1", language: .swift)
        #expect(outline.contains("[source_file]"))
        #expect(outline.contains("let x = 1"))
    }
}
