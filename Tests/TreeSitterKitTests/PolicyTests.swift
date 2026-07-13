import Foundation
import LanguageKit
import Testing
import TreeSitterCore
import TreeSitterStandardLanguages

/// Typed errors for unsupported languages, input-size limits, and the
/// language-support lookups RepoPrompt's call sites rely on.
@Suite struct PolicyTests {
    // MARK: - Unsupported languages throw a typed error

    @Test(arguments: [LanguageID.kotlin, .html, .markdown, LanguageID("klingon")])
    func unsupportedLanguageThrowsTypedError(language: LanguageID) async throws {
        let parser = try SyntaxParser.standard()
        await #expect(throws: SyntaxParserError.unsupportedLanguage(language)) {
            _ = try await parser.captures(in: "let x = 1", language: language)
        }
        await #expect(throws: SyntaxParserError.unsupportedLanguage(language)) {
            _ = try await parser.codeMapCaptures(in: "let x = 1", language: language)
        }
        await #expect(throws: SyntaxParserError.unsupportedLanguage(language)) {
            _ = try await parser.parseSummary(of: "let x = 1", language: language)
        }
    }

    @Test func emptyParserSupportsNothing() async throws {
        let parser = SyntaxParser(registrations: [])
        #expect(parser.supportedLanguages.isEmpty)
        await #expect(throws: SyntaxParserError.unsupportedLanguage(.swift)) {
            _ = try await parser.captures(in: "let x = 1", language: .swift)
        }
    }

    // MARK: - Language-support lookups (RepoPrompt call-site coverage)

    @Test func supportLookupsMatchRepoPromptCatalog() throws {
        let parser = try SyntaxParser.standard()
        #expect(parser.isSupported(.swift))
        #expect(parser.isSupported(.tsx))
        #expect(!parser.isSupported(.kotlin))

        // All 14 standard languages ship both query kinds.
        for language in StandardSyntaxLanguages.languages {
            #expect(parser.supportsHighlighting(language))
            #expect(parser.supportsCodeMap(language))
        }

        // RepoPrompt's isLightweight set: php, ruby, ts, tsx, js.
        let lightweight = Set(StandardSyntaxLanguages.languages.filter {
            parser.usesLightweightCodeMapExtraction($0)
        })
        #expect(lightweight == [.php, .ruby, .typescript, .tsx, .javascript])
    }

    @Test func extensionResolutionCoversRepoPromptExtensions() throws {
        let parser = try SyntaxParser.standard()
        // RepoPrompt's 14 canonical extensions resolve to the same languages.
        let expected: [String: LanguageID] = [
            "swift": .swift, "js": .javascript, "cs": .csharp, "py": .python,
            "c": .c, "rs": .rust, "cpp": .cpp, "go": .go, "java": .java,
            "dart": .dart, "ts": .typescript, "tsx": .tsx, "php": .php, "rb": .ruby,
        ]
        for (ext, language) in expected {
            #expect(parser.supportedLanguage(forFileExtension: ext) == language, "extension \(ext)")
        }
        // Case- and dot-insensitive via LanguageKit.
        #expect(parser.supportedLanguage(forFileExtension: ".SWIFT") == .swift)
        // Extensions whose language has no registration return nil.
        #expect(parser.supportedLanguage(forFileExtension: "kt") == nil)
        #expect(parser.supportedLanguage(forFileExtension: "nope") == nil)
    }

    // MARK: - Input-size limits

    @Test func lineCountLimitRefusesParse() async throws {
        let limits = SyntaxInputLimits.standard
        let content = String(repeating: "let x = 1\n", count: limits.maxLineCount + 1)
        let reason = limits.oversizeReason(for: content)
        guard case .lineCountExceeded(let actual, let limit)? = reason else {
            Issue.record("expected lineCountExceeded, got \(String(describing: reason))")
            return
        }
        #expect(actual == limit + 1)
        #expect(limit == 25_000)

        let parser = try SyntaxParser.standard()
        #expect(try await parser.codeMapCaptures(in: content, language: .swift).isEmpty)
        #expect(try await parser.parseSummary(of: content, language: .swift) == nil)
    }

    @Test func utf16LimitRefusesParse() throws {
        let limits = SyntaxInputLimits.standard
        // 1-byte scalars: UTF-8 stays under its limit, UTF-16 exceeds.
        let content = String(repeating: "a", count: limits.maxUTF16Length + 1)
        let reason = limits.oversizeReason(for: content)
        guard case .utf16LengthExceeded(let actual, let limit)? = reason else {
            Issue.record("expected utf16LengthExceeded, got \(String(describing: reason))")
            return
        }
        #expect(actual == limits.maxUTF16Length + 1)
        #expect(limit == 1_500_000)
    }

    @Test func utf8LimitIsCheckedFirst() throws {
        let limits = SyntaxInputLimits.standard
        // 4-byte emoji: exceeds UTF-8 (5.2M bytes) and UTF-16 (2.6M units);
        // UTF-8 must win because it is checked first (RepoPrompt's order).
        let content = String(repeating: "😀", count: 1_300_000)
        let reason = limits.oversizeReason(for: content)
        guard case .utf8SizeExceeded(_, let limit)? = reason else {
            Issue.record("expected utf8SizeExceeded, got \(String(describing: reason))")
            return
        }
        #expect(limit == 5_000_000)
    }

    @Test func crlfCountsAsSingleLineBreak() throws {
        var limits = SyntaxInputLimits.standard
        limits.maxLineCount = 3
        #expect(limits.oversizeReason(for: "a\r\nb\r\nc") == nil)
        #expect(limits.oversizeReason(for: "a\r\nb\r\nc\r\nd") == .lineCountExceeded(actual: 4, limit: 3))
        // Bare CR and bare LF also count.
        #expect(limits.oversizeReason(for: "a\rb\rc\rd") == .lineCountExceeded(actual: 4, limit: 3))
        #expect(limits.oversizeReason(for: "a\nb\nc\nd") == .lineCountExceeded(actual: 4, limit: 3))
    }

    @Test func highlightRefusesOverFiveThousandLinesButCodeMapAccepts() async throws {
        // 6 000 lines: over the highlight-only 5 000-line bail, under the
        // 25 000-line parse limit -- highlight returns [], code map still runs.
        let content = String(repeating: "func f() {}\n", count: 6_000)
        let parser = try SyntaxParser.standard()
        #expect(try await parser.captures(in: content, language: .swift).isEmpty)
        #expect(!(try await parser.codeMapCaptures(in: content, language: .swift)).isEmpty)
    }

    @Test func oversizeContentReturnsEmptyCapturesNotErrors() async throws {
        let parser = try SyntaxParser.standard()
        let content = String(repeating: "let x = 1\n", count: 26_000)
        #expect(parser.oversizeReason(for: content) != nil)
        #expect(try await parser.captures(in: content, language: .swift).isEmpty)
        #expect(try await parser.codeMapCaptures(in: content, language: .swift).isEmpty)
        #expect(try await parser.parseSummary(of: content, language: .swift) == nil)
    }

    // MARK: - Ad-hoc query errors

    @Test func malformedQueryThrowsTypedCompilationError() async throws {
        let parser = try SyntaxParser.standard()
        do {
            try await parser.compileQuery("(this_node_type_does_not_exist) @x", language: .swift)
            Issue.record("expected queryCompilationFailed")
        } catch let error as SyntaxParserError {
            guard case .queryCompilationFailed(let language, let kind, _) = error else {
                Issue.record("expected queryCompilationFailed, got \(error)")
                return
            }
            #expect(language == .swift)
            #expect(kind == .adHoc)
        }
    }
}
