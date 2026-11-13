import Foundation
import LanguageKit
import Testing
import TreeSitterCore
import TreeSitterStandardLanguages

/// Highlight and code-map queries carry `#eq?` / `#match?` predicates; a
/// capture whose predicate does not hold must not be reported.
@Suite struct HighlightPredicateTests {
    private func names(
        covering token: String,
        in content: String,
        captures: [SyntaxCapture]
    ) throws -> Set<String> {
        let range = (content as NSString).range(of: token)
        try #require(range.location != NSNotFound)
        return Set(captures.filter { $0.range == range }.map(\.name))
    }

    @Test func swiftTypeNameIsNotSelfBuiltin() async throws {
        let parser = try SyntaxParser.standard()
        let content = "let x: Foo = y\n"
        let captures = try await parser.captures(in: content, language: .swift)
        let names = try names(covering: "Foo", in: content, captures: captures)
        #expect(names.contains("type"))
        #expect(!names.contains("variable.builtin"), "#eq? \"Self\" must not match Foo: \(names)")
    }

    @Test func swiftSelfTypeIsBuiltin() async throws {
        let parser = try SyntaxParser.standard()
        let content = "func make() -> Self { fatalError() }\n"
        let captures = try await parser.captures(in: content, language: .swift)
        let names = try names(covering: "Self", in: content, captures: captures)
        #expect(names.contains("variable.builtin"))
    }

    @Test func swiftLowercaseReceiverIsNotType() async throws {
        let parser = try SyntaxParser.standard()
        let content = "let n = value.count\n"
        let captures = try await parser.captures(in: content, language: .swift)
        let names = try names(covering: "value", in: content, captures: captures)
        #expect(!names.contains("type"), "#match? \"^[A-Z]\" must not match value: \(names)")
    }

    @Test func pythonLowercaseIdentifierIsOnlyVariable() async throws {
        let parser = try SyntaxParser.standard()
        let content = "total = compute\n"
        let captures = try await parser.captures(in: content, language: .python)
        let names = try names(covering: "total", in: content, captures: captures)
        #expect(names.contains("variable"))
        #expect(!names.contains("constructor"), "\(names)")
        #expect(!names.contains("constant"), "\(names)")
    }

    @Test func pythonUppercaseIdentifierIsConstant() async throws {
        let parser = try SyntaxParser.standard()
        let content = "MAX_SIZE = 3\n"
        let captures = try await parser.captures(in: content, language: .python)
        let names = try names(covering: "MAX_SIZE", in: content, captures: captures)
        #expect(names.contains("constant"))
    }

    @Test func rubyCodeMapImportPredicateFiltersOtherCalls() async throws {
        let parser = try SyntaxParser.standard()
        let content = "require 'json'\nputs 'hi'\n"
        let captures = try await parser.codeMapCaptures(in: content, language: .ruby)
        let putsRange = (content as NSString).range(of: "puts")
        #expect(!captures.contains { $0.name == "import" && NSIntersectionRange($0.range, putsRange).length > 0 },
                "\(captures)")
    }
}
