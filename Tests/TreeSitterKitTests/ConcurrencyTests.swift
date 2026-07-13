import Foundation
import LanguageKit
import Testing
import TreeSitterCore
import TreeSitterStandardLanguages
import TreeSitterTestSupport

/// Concurrent captures calls produce results identical to serial runs -- the
/// actor serializes all tree-sitter work, and per-operation cursors keep
/// results deterministic.
@Suite struct ConcurrencyTests {
    @Test func twentyConcurrentMixedLanguageCapturesMatchSerialResults() async throws {
        let parser = try SyntaxParser.standard()
        let languages = StandardSyntaxLanguages.languages

        // 20 tasks cycling through all 14 languages.
        let work: [(index: Int, language: LanguageID, content: String)] = (0..<20).map { index in
            let language = languages[index % languages.count]
            let content = SyntaxTestFixtures.snippet(for: language)!
            return (index, language, content)
        }

        // Serial baseline.
        var serial: [Int: [SyntaxCapture]] = [:]
        for item in work {
            serial[item.index] = try await parser.captures(in: item.content, language: item.language)
        }

        // Concurrent run against the same parser instance.
        let concurrent = try await withThrowingTaskGroup(
            of: (Int, [SyntaxCapture]).self,
            returning: [Int: [SyntaxCapture]].self
        ) { group in
            for item in work {
                group.addTask {
                    (item.index, try await parser.captures(in: item.content, language: item.language))
                }
            }
            var results: [Int: [SyntaxCapture]] = [:]
            for try await (index, captures) in group {
                results[index] = captures
            }
            return results
        }

        #expect(concurrent.count == serial.count)
        for item in work {
            #expect(
                concurrent[item.index] == serial[item.index],
                "concurrent captures for task \(item.index) (\(item.language)) diverged from serial run"
            )
            #expect(!(serial[item.index] ?? []).isEmpty)
        }
    }

    @Test func concurrentMixedOperationsDoNotInterfere() async throws {
        let parser = try SyntaxParser.standard()
        let languages = StandardSyntaxLanguages.languages

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (offset, language) in languages.enumerated() {
                let content = SyntaxTestFixtures.snippet(for: language)!
                group.addTask {
                    if offset.isMultiple(of: 2) {
                        let highlight = try await parser.captures(in: content, language: language)
                        #expect(!highlight.isEmpty)
                    } else {
                        let codeMap = try await parser.codeMapCaptures(in: content, language: language)
                        #expect(!codeMap.isEmpty)
                    }
                    let summary = try await parser.parseSummary(of: content, language: language)
                    #expect(summary?.hasRootNode == true)
                }
            }
            try await group.waitForAll()
        }
    }
}
