# TreeSitterKit

Editor-neutral Tree-sitter parsing and syntax queries for Swift.

TreeSitterKit is the extraction of RepoPrompt's proven `SyntaxManager`
tree-sitter implementation into a reusable package. It parses source code,
runs highlight and code-map (structure-extraction) queries, and returns only
package-owned `Sendable` value types — no SwiftTreeSitter or grammar type
appears in any public signature. Language identity comes from
[LanguageKit](https://github.com/ajmcclary/LanguageKit).

## Products

The API is split so that a regular consumer imports only the first two
products and sees a clean parsing surface — no raw grammar pointers, no `.scm`
query text, no ad-hoc-query or tree-dump debug tools. Grammar authoring and
diagnostics are opt-in via their own products.

- **TreeSitterCore** — the stable parsing engine: `actor SyntaxParser`
  (construction, captures, summaries, capability lookups), `SyntaxCapture`,
  `SyntaxTreeSummary`, `SyntaxInputLimits`, typed `SyntaxParserError`, and the
  `SyntaxLanguageRegistration` type (its raw grammar/query members are
  authoring-only, gated behind `@_spi(GrammarAuthoring)`). Depends only on
  LanguageKit and SwiftTreeSitter; knows no grammars.
- **TreeSitterStandardLanguages** — the 14 languages RepoPrompt ships (Swift,
  JavaScript, TypeScript, TSX, Python, Go, Rust, C, C++, Java, C#, Dart, PHP,
  Ruby): builds a configured `SyntaxParser` via `SyntaxParser.standard()` and
  exposes their capability metadata. Highlight/code-map query text is bundled
  as SwiftPM resources but is **not** part of this product's public surface.
- **TreeSitterGrammarAuthoring** — the public path to *custom* grammar
  authoring: constructing custom `SyntaxLanguageRegistration`s (raw
  grammar-pointer closures) via `GrammarAuthoring.makeRegistration`. Depends on
  **TreeSitterCore only** — importing it does *not* resolve or link the 14
  bundled grammars, so custom-grammar authors stay lightweight.
- **TreeSitterStandardLanguagesAuthoring** — the public path to the standard
  languages' *authoring* surface: reading their bundled `.scm` query sources via
  `StandardLanguagesAuthoring.standardLanguageQuerySources()` and their raw
  registrations via `StandardLanguagesAuthoring.standardRegistrations()`. Links
  **TreeSitterStandardLanguages** (and therefore the bundled grammars); kept
  separate from TreeSitterGrammarAuthoring so custom-grammar authors are not
  forced to resolve every standard grammar.
- **TreeSitterDiagnostics** — the public path to ad-hoc query
  compilation/execution and parse-tree inspection: `SyntaxParser.compileQuery`,
  `runQuery` (→ `SyntaxQueryRun`), `syntaxTreeDescription`, and `nodeOutline`.
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

`TreeSitterCore` is grammar-agnostic. Registration construction is a
grammar-authoring concern, so it lives in the **TreeSitterGrammarAuthoring**
product. Build a registration whose `grammar` closure returns the generated
`tree_sitter_<lang>()` pointer erased to `UnsafeRawPointer`:

```swift
import TreeSitterCore
import TreeSitterGrammarAuthoring

let registration = GrammarAuthoring.makeRegistration(
    language: LanguageID("mylang"),
    grammar: { tree_sitter_mylang().map(UnsafeRawPointer.init) },
    highlightQuerySource: highlightsSCM,
    codeMapQuerySource: nil
)
let parser = SyntaxParser(registrations: [registration])
```

## Diagnostics

Ad-hoc query and parse-tree inspection tools are opt-in via the
**TreeSitterDiagnostics** product:

```swift
import TreeSitterCore
import TreeSitterStandardLanguages
import TreeSitterDiagnostics

let parser = try SyntaxParser.standard()
try await parser.compileQuery(querySCM, language: .swift)   // validate a query
let run = try await parser.runQuery(querySCM, on: source, language: .swift)
let tree = try await parser.syntaxTreeDescription(of: source, language: .swift)
let outline = try await parser.nodeOutline(of: source, language: .swift)
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

**Consume by revision, not by version.** SwiftPM rejects a stable-version
dependency on any package whose own dependencies are revision-pinned, and
TreeSitterKit's grammar pins are deliberately exact revisions (see above). So
`.package(url: …, from: "0.1.0")` will fail to resolve; depend on an exact
revision instead — release tags like `0.1.0` mark the commits to pin:

```swift
.package(
    url: "https://github.com/ajmcclary/TreeSitterKit.git",
    revision: "b6f181766b48c7416d50874ae0a84af333ad0097"  // tag 0.1.0
)
```

## License

MIT (see [`LICENSE`](LICENSE)). Bundled grammar attribution and license
copies: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and
[`ThirdPartyLicenses/tree-sitter/`](ThirdPartyLicenses/tree-sitter/).
