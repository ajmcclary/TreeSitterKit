import Foundation
import LanguageKit
import Testing
import TreeSitterCore
import TreeSitterStandardLanguages

/// Capture ranges are UTF-16 `NSRange`s that stay correct in the presence of
/// multi-byte characters, emoji (surrogate pairs), and CRLF line endings.
@Suite struct RangeCorrectnessTests {
    /// Finds the first capture whose text equals `token`, asserting its range
    /// matches the NSString range of that token.
    private func expectCapture(
        matching token: String,
        in content: String,
        language: LanguageID,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let parser = try SyntaxParser.standard()
        let captures = try await parser.captures(in: content, language: language)
        #expect(!captures.isEmpty, sourceLocation: sourceLocation)

        let texts: [String] = captures.compactMap { capture in
            guard let range = Range(capture.range, in: content) else { return nil }
            return String(content[range])
        }
        #expect(texts.count == captures.count, "every capture range must be a valid UTF-16 range", sourceLocation: sourceLocation)
        #expect(texts.contains(token), "expected a capture over \(token); got \(texts)", sourceLocation: sourceLocation)

        let expectedRange = (content as NSString).range(of: token)
        let match = captures.first { $0.range == expectedRange }
        #expect(
            match != nil,
            "expected a capture at NSString range \(expectedRange) of \(token)",
            sourceLocation: sourceLocation
        )
    }

    @Test func multiByteCharactersBeforeTokenDoNotSkewRanges() async throws {
        // "é" is 1 UTF-16 unit / 2 UTF-8 bytes; "ü" likewise. If byte offsets
        // leaked through unconverted, the "func" range would be off by 4.
        let content = "// héllö wörld comment\nfunc greet() {}"
        try await expectCapture(matching: "func", in: content, language: .swift)
    }

    @Test func emojiBeforeTokenDoNotSkewRanges() async throws {
        // "👋🏽" is 4 UTF-16 units / 8 UTF-8 bytes; a byte-offset leak would
        // shift the "func" range by 4 units.
        let content = "let wave = \"👋🏽 hello 🌍\"\nfunc greet() {}"
        try await expectCapture(matching: "func", in: content, language: .swift)
    }

    @Test func crlfLineEndingsDoNotSkewRanges() async throws {
        let content = "// first line\r\n// second line\r\nfunc greet() {}\r\n"
        try await expectCapture(matching: "func", in: content, language: .swift)
    }

    @Test func emojiAndCRLFCombinedInJavaScript() async throws {
        let content = "// 😀😀😀 header\r\nconst s = \"héllo\";\r\nfunction add(a, b) { return a + b; }\r\n"
        try await expectCapture(matching: "function", in: content, language: .javascript)
    }

    @Test func multiByteIdentifiersRoundTripThroughCaptureRanges() async throws {
        // Identifiers containing non-ASCII text: every capture range must
        // still slice the source cleanly.
        let content = "def grüße():\n    return \"héllo 👋\"\n"
        let parser = try SyntaxParser.standard()
        let captures = try await parser.captures(in: content, language: .python)
        #expect(!captures.isEmpty)
        for capture in captures {
            #expect(Range(capture.range, in: content) != nil)
        }
    }

    @Test func codeMapRangesAreValidWithEmoji() async throws {
        let content = "class Greeter:\n    \"\"\"👋 docs\"\"\"\n    def wave(self):\n        return \"👋🏽\"\n"
        let parser = try SyntaxParser.standard()
        let captures = try await parser.codeMapCaptures(in: content, language: .python)
        #expect(!captures.isEmpty)
        let texts: [String] = captures.compactMap { capture in
            guard let range = Range(capture.range, in: content) else { return nil }
            return String(content[range])
        }
        #expect(texts.count == captures.count)
        #expect(texts.contains { $0.contains("wave") || $0.contains("Greeter") })
    }
}
