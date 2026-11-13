import Foundation
import LanguageKit
import Testing
@_spi(GrammarAuthoring) import TreeSitterCore
@_spi(GrammarAuthoring) import TreeSitterStandardLanguages

/// Every `#match?` / `#not-match?` pattern in every bundled query must be the
/// regular expression its author meant. Predicates are evaluated since
/// 0.3.1, so a typo silently changes highlighting or code maps.
@Suite struct QueryPredicateRegexTests {
    struct RegexPredicate: CustomStringConvertible {
        let file: String
        let line: Int
        /// The string as written in the `.scm` file, between the quotes.
        let raw: String
        /// The string tree-sitter hands to the predicate.
        let value: String

        var description: String { "\(file):\(line) \"\(raw)\"" }
    }

    /// Tree-sitter string escapes: `\n`, `\r`, `\t`, `\0`; any other `\x`
    /// becomes `x` (the backslash is dropped).
    private static func unescape(_ raw: String) -> String {
        var result = ""
        var escaped = false
        for character in raw {
            if escaped {
                switch character {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "0": result.append("\0")
                default: result.append(character)
                }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// Tokenizes a query just enough to find each `#match?`/`#not-match?`
    /// and its first string argument (skipping `;` comments and strings).
    private static func regexPredicates(in source: String, file: String) -> [RegexPredicate] {
        scan(source, file: file).regexes
    }

    /// Every `#name` (predicate or directive) in a query, with its line.
    private static func predicateNames(in source: String, file: String) -> [(name: String, location: String)] {
        scan(source, file: file).names
    }

    private static func scan(
        _ source: String,
        file: String
    ) -> (regexes: [RegexPredicate], names: [(name: String, location: String)]) {
        var names: [(name: String, location: String)] = []
        var predicates: [RegexPredicate] = []
        let characters = Array(source)
        var index = 0
        var line = 1
        var pendingRegexPredicate = false

        while index < characters.count {
            let character = characters[index]
            switch character {
            case "\n":
                line += 1
                index += 1

            case ";":
                while index < characters.count, characters[index] != "\n" { index += 1 }

            case "\"":
                let startLine = line
                var raw = ""
                index += 1
                while index < characters.count, characters[index] != "\"" {
                    if characters[index] == "\\", index + 1 < characters.count {
                        raw.append(characters[index])
                        index += 1
                    }
                    raw.append(characters[index])
                    index += 1
                }
                index += 1
                if pendingRegexPredicate {
                    predicates.append(RegexPredicate(file: file, line: startLine, raw: raw, value: unescape(raw)))
                    pendingRegexPredicate = false
                }

            case "#":
                var name = ""
                index += 1
                while index < characters.count, !characters[index].isWhitespace, characters[index] != ")" {
                    name.append(characters[index])
                    index += 1
                }
                names.append((name: name, location: "\(file):\(line)"))
                pendingRegexPredicate = name == "match?" || name == "not-match?"

            default:
                index += 1
            }
        }
        return (predicates, names)
    }

    private static func allQuerySources() throws -> [(file: String, source: String)] {
        var sources: [(file: String, source: String)] = []
        for registration in try StandardSyntaxLanguages.registrations() {
            if let source = registration.highlightQuerySource {
                sources.append((file: "\(registration.language)/highlights.scm", source: source))
            }
            if let source = registration.codeMapQuerySource {
                sources.append((file: "\(registration.language)/codemap.scm", source: source))
            }
        }
        return sources
    }

    /// Predicates and directives the evaluator implements: SwiftTreeSitter's
    /// built-ins plus TreeSitterKit's `#not-kind?`. Any other name parses as
    /// a generic predicate that always passes, so a misspelling such as
    /// `#not-kid?` would ship as a silent no-op.
    static let implementedPredicateNames: Set<String> = [
        "eq?", "not-eq?", "match?", "not-match?", "any-of?", "not-any-of?", "is-not?", "set!",
        "not-kind?"
    ]

    @Test func everyPredicateNameIsImplemented() throws {
        var seen = 0
        for (file, source) in try Self.allQuerySources() {
            for (name, location) in Self.predicateNames(in: source, file: file) {
                seen += 1
                #expect(Self.implementedPredicateNames.contains(name), "\(location): #\(name) is not implemented")
            }
        }
        #expect(seen >= 30)
    }

    @Test func aMisspelledPredicateNameIsReported() {
        let names = Self.predicateNames(in: "((identifier) @x (#not-kid? @x \"a\"))\n; (#bogus? @x)", file: "t.scm")
        #expect(names.map(\.name) == ["not-kid?"])
        #expect(!Self.implementedPredicateNames.contains("not-kid?"))
    }

    private static func allRegexPredicates() throws -> [RegexPredicate] {
        var predicates: [RegexPredicate] = []
        for registration in try StandardSyntaxLanguages.registrations() {
            if let source = registration.highlightQuerySource {
                predicates += regexPredicates(in: source, file: "\(registration.language)/highlights.scm")
            }
            if let source = registration.codeMapQuerySource {
                predicates += regexPredicates(in: source, file: "\(registration.language)/codemap.scm")
            }
        }
        return predicates
    }

    @Test func theBundledQueriesHaveRegexPredicates() throws {
        // Guards the scan itself: an empty result would make the checks below vacuous.
        #expect(try Self.allRegexPredicates().count >= 30)
    }

    @Test func everyRegexCompiles() throws {
        for predicate in try Self.allRegexPredicates() {
            #expect(throws: Never.self, "\(predicate)") {
                _ = try NSRegularExpression(pattern: predicate.value)
            }
        }
    }

    /// A backslash before anything but `\`, `"`, `n`, `r`, `t`, `0` is
    /// dropped by tree-sitter, so `"\d"` reaches the regex as `d`; a regex
    /// escape must be written `"\\d"`.
    @Test func noRegexEscapeIsLostToTheQueryStringSyntax() throws {
        for predicate in try Self.allRegexPredicates() {
            var lost: [String] = []
            var characters = Array(predicate.raw)[...]
            while let character = characters.popFirst() {
                guard character == "\\", let next = characters.popFirst() else { continue }
                if !"\\\"nrt0".contains(next) {
                    lost.append("\\\(next)")
                }
            }
            #expect(lost.isEmpty, "\(predicate): tree-sitter drops the backslash of \(lost)")
        }
    }

    @Test func noRegexHasAnUnbalancedQuote() throws {
        for predicate in try Self.allRegexPredicates() {
            for quote in ["'", "\""] {
                let count = predicate.value.components(separatedBy: quote).count - 1
                #expect(count.isMultiple(of: 2), "\(predicate): unbalanced \(quote)")
            }
        }
    }

    /// `MAX_SIZE` and `HTTP2_PORT` are constants by the Rust query's
    /// convention (an upper-case letter followed by upper-case letters,
    /// digits or `_`); `Foo` (a type/constructor), `x` and the single
    /// letter `A` are not.
    @Test func rustAllCapsNamesAreConstants() async throws {
        let parser = try SyntaxParser.standard()
        let source = "fn main() {\n    let x = MAX_SIZE + HTTP2_PORT;\n    let y = Foo::new(A);\n}\n"
        let captures = try await parser.captures(in: source, language: .rust)
        let text = source as NSString
        let constants = Set(captures.filter { $0.name == "constant" }.map { text.substring(with: $0.range) })
        #expect(constants == ["MAX_SIZE", "HTTP2_PORT"])
    }
}
