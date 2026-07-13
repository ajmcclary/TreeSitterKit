# TreeSitterKit

Editor-neutral Tree-sitter parsing and syntax queries for Swift.

TreeSitterKit is the extraction of RepoPrompt's proven `SyntaxManager`
tree-sitter implementation into a reusable package. It parses source code,
runs highlight and code-map (structure-extraction) queries, and returns only
package-owned `Sendable` value types — no SwiftTreeSitter or grammar type
appears in any public signature. Language identity comes from
[LanguageKit](https://github.com/ajmcclary/LanguageKit).

## Products

- **TreeSitterCore** — the parsing engine: `actor SyntaxParser`,
  `SyntaxCapture`, `SyntaxTreeSummary`, `SyntaxLanguageRegistration`,
  `SyntaxInputLimits`, typed `SyntaxParserError`. Depends only on LanguageKit
  and SwiftTreeSitter; knows no grammars.
- **TreeSitterStandardLanguages** — registrations for the 14 languages
  RepoPrompt ships (Swift, JavaScript, TypeScript, TSX, Python, Go, Rust, C,
  C++, Java, C#, Dart, PHP, Ruby), with their highlight and code-map query
  text bundled as SwiftPM resources.
- **TreeSitterTestSupport** — representative per-language source fixtures for
  consumers' tests.

## Usage

```swift
import TreeSitterCore
import TreeSitterStandardLanguages

let parser = try SyntaxParser.standard()

// Highlight captures (UTF-16 NSRanges into the source string)
let highlights = try await parser.captures(in: source, language: .swift)

// Code-map (structure) captures
let outline = try await parser.codeMapCaptures(in: source, language: .swift)

// Value-only parse summary
let summary = try await parser.parseSummary(of: source, language: .swift)

// Language support lookups (nonisolated, no await)
parser.isSupported(.ruby)                        // true
parser.supportsCodeMap(.tsx)                     // true
parser.supportedLanguage(forFileExtension: "rs") // .rust
```

Unsupported languages throw the typed error
`SyntaxParserError.unsupportedLanguage(_:)`. Oversized inputs (per
`SyntaxInputLimits.standard`, RepoPrompt's shipping thresholds) return empty
captures / `nil` summaries rather than erroring; ask
`parser.oversizeReason(for:)` why.

## Concurrency model

`SyntaxParser` is an actor: all tree-sitter work (parsers, compiled queries,
and especially stateful query cursors) is serialized behind actor isolation,
and every cursor is created, consumed, and discarded within a single isolated
call. Concurrent callers are safe and produce results identical to serial
runs.

## Custom languages

`TreeSitterCore` is grammar-agnostic. Register your own language by supplying
a `SyntaxLanguageRegistration` whose `grammar` closure returns the generated
`tree_sitter_<lang>()` pointer erased to `UnsafeRawPointer`:

```swift
let registration = SyntaxLanguageRegistration(
    language: LanguageID("mylang"),
    grammar: { tree_sitter_mylang().map(UnsafeRawPointer.init) },
    highlightQuerySource: highlightsSCM,
    codeMapQuerySource: nil
)
let parser = SyntaxParser(registrations: [registration])
```

## Dependency pins

SwiftTreeSitter is pinned exactly at `ChimeHQ/SwiftTreeSitter@0.8.0` and every
grammar package at the exact revision RepoPrompt ships — see `Package.swift`.
Query text and node-type names are grammar-revision-sensitive; do not upgrade
pins without re-validating the bundled queries.

The pinned JavaScript and Python grammar packages omit their external-scanner
objects under clean SwiftPM resolutions; the `TreeSitterKitScannerSupport`
target carries copies of just those scanner sources (see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)).

**Hazard for consumers:** if your app compiles its own copies of the JS/Python
external scanners (e.g. via a direct grammar-package dependency) while also
linking `TreeSitterStandardLanguages`, the linker will hit duplicate
`tree_sitter_{javascript,python}_external_scanner_*` symbols. Drop your own
copies and rely on `TreeSitterKitScannerSupport`'s instead.

## License

MIT (see [`LICENSE`](LICENSE)). Bundled grammar attribution and license
copies: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and
[`ThirdPartyLicenses/tree-sitter/`](ThirdPartyLicenses/tree-sitter/).
