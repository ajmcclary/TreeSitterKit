# Vendored Tree-sitter grammars

The 14 standard-language grammars are **vendored** into TreeSitterKit: their
generated C parser (`src/parser.c`), external scanner (`src/scanner.c`, where the
grammar has one), the private `src/tree_sitter/*.h` runtime headers, and the
public Swift binding header (`include/<lang>.h`, declaring `tree_sitter_<lang>()`)
are committed here under `Sources/Grammars/<Module>/`. Nothing else from upstream
is copied — no `queries/`, `grammar.json`, `node-types.json`, tests, or other
language bindings.

Every vendored file is **byte-identical** to the file at the pinned upstream
revision below (verified with `shasum -a 256`; see
[`VENDORED.sha256`](VENDORED.sha256)). No source was edited — not even include
paths: each grammar keeps its `src/tree_sitter/` headers next to its `parser.c`,
and TypeScript/TSX keep their upstream nested `<lang>/src/` + sibling `common/`
layout so `scanner.c`'s `#include "../../common/scanner.h"` resolves untouched.

This is what makes TreeSitterKit **semver-consumable**: there are no
revision- or branch-pinned SwiftPM dependencies. Bumping a grammar is therefore
a deliberate, reviewable act — re-run the procedure below.

## Provenance

The `typescript` package provides **two** grammars (and two vendored targets):
`TreeSitterTypeScript` and `TreeSitterTSX`. All other packages provide one.

| Grammar | Upstream repository | Vendored revision | Vendored target(s) | License |
| --- | --- | --- | --- | --- |
| C | <https://github.com/tree-sitter/tree-sitter-c> | `3efee11f784605d44623d7dadd6cd12a0f73ea92` | `TreeSitterC` | MIT ([`LICENSE`](TreeSitterC/LICENSE)) |
| C# | <https://github.com/tree-sitter/tree-sitter-c-sharp.git> | `b27b091bfdc5f16d0ef76421ea5609c82a57dff0` | `TreeSitterCSharp` | MIT ([`LICENSE`](TreeSitterCSharp/LICENSE)) |
| C++ | <https://github.com/tree-sitter/tree-sitter-cpp> | `e5cea0ec884c5c3d2d1e41a741a66ce13da4d945` | `TreeSitterCPP` | MIT ([`LICENSE`](TreeSitterCPP/LICENSE)) |
| Dart | <https://github.com/UserNobody14/tree-sitter-dart> | `80e23c07b64494f7e21090bb3450223ef0b192f4` | `TreeSitterDart` | MIT ([`LICENSE`](TreeSitterDart/LICENSE)) |
| Go | <https://github.com/tree-sitter/tree-sitter-go> | `c350fa54d38af725c40d061a602ee3205ef1e072` | `TreeSitterGo` | MIT ([`LICENSE`](TreeSitterGo/LICENSE)) |
| Java | <https://github.com/tree-sitter/tree-sitter-java> | `e10607b45ff745f5f876bfa3e94fbcc6b44bdc11` | `TreeSitterJava` | MIT ([`LICENSE`](TreeSitterJava/LICENSE)) |
| JavaScript | <https://github.com/tree-sitter/tree-sitter-javascript> | `39798e26b6d4dbcee8e522b8db83f8b2df33a5ea` | `TreeSitterJavaScript` | MIT ([`LICENSE`](TreeSitterJavaScript/LICENSE)) |
| PHP | <https://github.com/provencher/tree-sitter-php> | `0a99deca13c4af1fb9adcb03c958bfc9f4c740a9` | `TreeSitterPHP` | MIT ([`LICENSE`](TreeSitterPHP/LICENSE)) |
| Python | <https://github.com/tree-sitter/tree-sitter-python> | `c5fca1a186e8e528115196178c28eefa8d86b0b0` | `TreeSitterPython` | MIT ([`LICENSE`](TreeSitterPython/LICENSE)) |
| Ruby | <https://github.com/tree-sitter/tree-sitter-ruby> | `7a010836b74351855148818d5cb8170dc4df8e6a` | `TreeSitterRuby` | MIT ([`LICENSE`](TreeSitterRuby/LICENSE)) |
| Rust | <https://github.com/tree-sitter/tree-sitter-rust> | `2eaf126458a4d6a69401089b6ba78c5e5d6c1ced` | `TreeSitterRust` | MIT ([`LICENSE`](TreeSitterRust/LICENSE)) |
| Swift | <https://github.com/alex-pinkus/tree-sitter-swift> | `9253825dd2570430b53fa128cbb40cb62498e75d` | `TreeSitterSwift` | MIT ([`LICENSE`](TreeSitterSwift/LICENSE)) |
| TypeScript / TSX | <https://github.com/tree-sitter/tree-sitter-typescript> | `75b3874edb2dc714fb1fd77a32013d0f8699989f` | `TreeSitterTypeScript`, `TreeSitterTSX` | MIT ([`LICENSE`](TreeSitterTypeScript/LICENSE)) |

Thirteen grammar packages, fourteen grammars/targets. The same revisions are
mirrored in the superproject's `Scripts/treesitter-grammar-pins.txt` allowlist,
which `Scripts/check-dependency-policy` cross-checks against this table.

Full license copies are also collected under
[`../../ThirdPartyLicenses/tree-sitter/`](../../ThirdPartyLicenses/tree-sitter)
(where C, C++, Go, and JavaScript share one identical MIT copy).

## Layout of a vendored target

Flat grammars (all except TypeScript/TSX):

```
Sources/Grammars/<Module>/
  include/<lang>.h          # public binding header → publicHeadersPath
  src/parser.c              # compiled
  src/scanner.c             # compiled (only if the grammar has an external scanner)
  src/tree_sitter/*.h       # private runtime headers, reached via headerSearchPath("src")
  LICENSE                   # upstream license (excluded from the build in Package.swift)
```

TypeScript and TSX keep the upstream nested shape so the shared scanner include
resolves without edits:

```
Sources/Grammars/TreeSitterTypeScript/
  include/typescript.h
  common/scanner.h          # shared by both grammars; #include "../../common/scanner.h"
  typescript/src/{parser.c,scanner.c,tree_sitter/*.h}
  LICENSE
Sources/Grammars/TreeSitterTSX/
  include/tsx.h
  common/scanner.h
  tsx/src/{parser.c,scanner.c,tree_sitter/*.h}
  LICENSE
```

Which grammars have an external scanner is encoded in `Package.swift` (the
`vendoredGrammar(_:scanner:)` helper's `scanner:` flag, and the two explicit
TypeScript/TSX targets).

## Re-vendoring procedure (updating a grammar deliberately)

1. **Pick the new revision.** Choose the exact upstream commit SHA (40 hex
   chars). Query text and node-type names are grammar-revision-sensitive, so
   also re-check the bundled `.scm` queries in
   `Sources/TreeSitterStandardLanguages/Queries/<lang>/` still compile against
   it (the test suite does this).
2. **Clone at that revision** into a scratch dir and read the upstream
   `Package.swift` to learn exactly which files its target compiles
   (`sources:`), its `publicHeadersPath`, and any `headerSearchPath`.
3. **Copy only the compile inputs + license**, preserving relative layout:
   the listed `parser.c`/`scanner.c`, the whole `src/tree_sitter/` header
   directory, the public `bindings/swift/.../<lang>.h` into `include/`, and
   `LICENSE`. Do **not** copy queries, JSON, tests, or other bindings. If the
   scanner uses a relative include (as TypeScript/TSX do), preserve the
   directory nesting that include depends on rather than editing the source.
4. **Record checksums.** `shasum -a 256` each copied file against its upstream
   source; they must match byte-for-byte. Regenerate
   [`VENDORED.sha256`](VENDORED.sha256).
5. **Update this table**, the superproject `Scripts/treesitter-grammar-pins.txt`
   allowlist, and (if the module set changed) `Package.swift`.
6. **Verify behavior.** `rm -rf .build && swift build && swift test` — all
   35 tests green — and run `Scripts/check-dependency-policy` in the
   superproject.
