# Tree-sitter Attribution Bundle

TreeSitterKit links Tree-sitter grammar package products and the
`SwiftTreeSitter` wrapper/runtime through its SwiftPM dependency graph. This
directory contains curated license copies for those components, carried over
from RepoPrompt (the application this package was extracted from) and kept in
sync with TreeSitterKit's `Package.swift` pins.

All grammar dependencies use source-preserving SwiftPM revision pins: the
selected upstream snapshots retain generated parser source and their license
files. A source-preserving pin improves reproducibility, but package
dependencies still require attribution when distributed.

## Grammar packages

| Grammar | Upstream repository | Exact revision | SwiftPM product (modules where useful) | License copy |
| --- | --- | --- | --- | --- |
| C | <https://github.com/tree-sitter/tree-sitter-c> | `3efee11f784605d44623d7dadd6cd12a0f73ea92` | `TreeSitterC` | [`LICENSE-tree-sitter-max-brunsfeld-2014.txt`](LICENSE-tree-sitter-max-brunsfeld-2014.txt) |
| C# | <https://github.com/tree-sitter/tree-sitter-c-sharp.git> | `b27b091bfdc5f16d0ef76421ea5609c82a57dff0` | `TreeSitterCSharp` | [`LICENSE-tree-sitter-c-sharp.txt`](LICENSE-tree-sitter-c-sharp.txt) |
| C++ | <https://github.com/tree-sitter/tree-sitter-cpp> | `e5cea0ec884c5c3d2d1e41a741a66ce13da4d945` | `TreeSitterCPP` | [`LICENSE-tree-sitter-max-brunsfeld-2014.txt`](LICENSE-tree-sitter-max-brunsfeld-2014.txt) |
| Dart | <https://github.com/UserNobody14/tree-sitter-dart> | `80e23c07b64494f7e21090bb3450223ef0b192f4` | `TreeSitterDart` | [`LICENSE-tree-sitter-dart.txt`](LICENSE-tree-sitter-dart.txt) |
| Go | <https://github.com/tree-sitter/tree-sitter-go> | `c350fa54d38af725c40d061a602ee3205ef1e072` | `TreeSitterGo` | [`LICENSE-tree-sitter-max-brunsfeld-2014.txt`](LICENSE-tree-sitter-max-brunsfeld-2014.txt) |
| Java | <https://github.com/tree-sitter/tree-sitter-java> | `e10607b45ff745f5f876bfa3e94fbcc6b44bdc11` | `TreeSitterJava` | [`LICENSE-tree-sitter-java.txt`](LICENSE-tree-sitter-java.txt) |
| JavaScript | <https://github.com/tree-sitter/tree-sitter-javascript> | `39798e26b6d4dbcee8e522b8db83f8b2df33a5ea` | `TreeSitterJavaScript` | [`LICENSE-tree-sitter-max-brunsfeld-2014.txt`](LICENSE-tree-sitter-max-brunsfeld-2014.txt) |
| PHP | <https://github.com/provencher/tree-sitter-php> | `0a99deca13c4af1fb9adcb03c958bfc9f4c740a9` | `TreeSitterPHP` | [`LICENSE-tree-sitter-php.txt`](LICENSE-tree-sitter-php.txt) |
| Python | <https://github.com/tree-sitter/tree-sitter-python> | `c5fca1a186e8e528115196178c28eefa8d86b0b0` | `TreeSitterPython` | [`LICENSE-tree-sitter-python.txt`](LICENSE-tree-sitter-python.txt) |
| Ruby | <https://github.com/tree-sitter/tree-sitter-ruby> | `7a010836b74351855148818d5cb8170dc4df8e6a` | `TreeSitterRuby` | [`LICENSE-tree-sitter-ruby.txt`](LICENSE-tree-sitter-ruby.txt) |
| Rust | <https://github.com/tree-sitter/tree-sitter-rust> | `2eaf126458a4d6a69401089b6ba78c5e5d6c1ced` | `TreeSitterRust` | [`LICENSE-tree-sitter-rust.txt`](LICENSE-tree-sitter-rust.txt) |
| Swift | <https://github.com/alex-pinkus/tree-sitter-swift> | `9253825dd2570430b53fa128cbb40cb62498e75d` | `TreeSitterSwift` | [`LICENSE-tree-sitter-swift.txt`](LICENSE-tree-sitter-swift.txt) |
| TypeScript / TSX | <https://github.com/tree-sitter/tree-sitter-typescript> | `75b3874edb2dc714fb1fd77a32013d0f8699989f` | `TreeSitterTypeScript` (`TreeSitterTypeScript`, `TreeSitterTSX` modules) | [`LICENSE-tree-sitter-typescript.txt`](LICENSE-tree-sitter-typescript.txt) |

The C, C++, Go, and JavaScript snapshots contain identical MIT license text,
so they intentionally share one copy
(`LICENSE-tree-sitter-max-brunsfeld-2014.txt`).

## JavaScript and Python scanner linker compatibility sources

See the "JavaScript and Python scanner linker compatibility sources" section
of the repository-root [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md)
for the `Sources/TreeSitterKitScannerSupport` target's provenance.
[`scanner-support.sha256`](scanner-support.sha256) records the copied-file
checksums.

## Swift wrapper, embedded runtime, and ICU subset

The `SwiftTreeSitter` package includes the C Tree-sitter runtime as a
submodule and compiles its `tree-sitter/lib` target. That runtime snapshot
includes a small subset of ICU headers and the corresponding full ICU notice
file.

| Component | Source | Resolved revision | License copy |
| --- | --- | --- | --- |
| `SwiftTreeSitter` (`0.8.0`) | <https://github.com/ChimeHQ/SwiftTreeSitter.git> | `2599e95310b3159641469d8a21baf2d3d200e61f` | [`LICENSE-SwiftTreeSitter.txt`](LICENSE-SwiftTreeSitter.txt) |
| Embedded Tree-sitter runtime | <https://github.com/tree-sitter/tree-sitter.git> | `0c49d6745b3fc4822ab02e0018770cd6383a779c` | [`LICENSE-tree-sitter-runtime.txt`](LICENSE-tree-sitter-runtime.txt) |
| ICU subset embedded by that runtime | <https://github.com/unicode-org/icu> | `552b01f61127d30d6589aa4bf99468224979b661` recorded by the runtime's `ICU_SHA` | [`LICENSE-tree-sitter-runtime-ICU.txt`](LICENSE-tree-sitter-runtime-ICU.txt) |

The ICU file is preserved in full because it contains the applicable ICU
copyright and permission notice plus additional third-party notices.
