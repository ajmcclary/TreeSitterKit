# Third-Party Notices

## Tree-sitter grammar packages and runtime

TreeSitterKit links thirteen Tree-sitter grammar SwiftPM packages and the
`SwiftTreeSitter` wrapper (with its embedded Tree-sitter C runtime) through
fixed, source-preserving revision pins. Those package dependencies require
attribution when distributed.

The curated [`ThirdPartyLicenses/tree-sitter/`](ThirdPartyLicenses/tree-sitter/)
bundle maps the directly linked grammar products to their exact upstream
repositories and revisions, and includes full license copies for the grammar
packages, `SwiftTreeSitter`, its embedded Tree-sitter runtime, and the ICU
subset notice shipped with that runtime.

## JavaScript and Python scanner linker compatibility sources

Clean SwiftPM resolutions of the exact-pinned upstream JavaScript and Python
grammar packages compile their parser objects but omit their external-scanner
objects (each package's manifest probes `src/scanner.c` with a cwd-relative
`FileManager` check that fails during manifest evaluation). TreeSitterKit
therefore carries a narrow `Sources/TreeSitterKitScannerSupport` C target
containing copies of only the missing upstream scanner implementations and
their required helper headers, taken from RepoPrompt's proven
`TreeSitterScannerSupport` subtree (upstream sources with minimal
compile-hygiene adjustments: `(void)` prototypes and explicit integer casts).
The upstream package URLs, revisions, and products remain unchanged.

| TreeSitterKit source path | Upstream snapshot source | Applicable license copy |
| --- | --- | --- |
| `Sources/TreeSitterKitScannerSupport/src/javascript/scanner.c` | `tree-sitter-javascript/src/scanner.c` at `39798e26b6d4dbcee8e522b8db83f8b2df33a5ea` | [`LICENSE-tree-sitter-max-brunsfeld-2014.txt`](ThirdPartyLicenses/tree-sitter/LICENSE-tree-sitter-max-brunsfeld-2014.txt) |
| `Sources/TreeSitterKitScannerSupport/src/python/scanner.c` | `tree-sitter-python/src/scanner.c` at `c5fca1a186e8e528115196178c28eefa8d86b0b0` | [`LICENSE-tree-sitter-python.txt`](ThirdPartyLicenses/tree-sitter/LICENSE-tree-sitter-python.txt) |
| `Sources/TreeSitterKitScannerSupport/include/tree_sitter/parser.h` | Byte-identical in both exact snapshots above | Same grammar license copies above |
| `Sources/TreeSitterKitScannerSupport/include/tree_sitter/array.h` | `tree-sitter-python/src/tree_sitter/array.h` at `c5fca1a186e8e528115196178c28eefa8d86b0b0` | [`LICENSE-tree-sitter-python.txt`](ThirdPartyLicenses/tree-sitter/LICENSE-tree-sitter-python.txt) |
| `Sources/TreeSitterKitScannerSupport/include/tree_sitter/alloc.h` | `tree-sitter-python/src/tree_sitter/alloc.h` at `c5fca1a186e8e528115196178c28eefa8d86b0b0` | [`LICENSE-tree-sitter-python.txt`](ThirdPartyLicenses/tree-sitter/LICENSE-tree-sitter-python.txt) |

[`ThirdPartyLicenses/tree-sitter/scanner-support.sha256`](ThirdPartyLicenses/tree-sitter/scanner-support.sha256)
records the copied-file checksums. Remove this compatibility target, its
checksum file, and this documentation section together only after validated
upstream revisions or SwiftPM behavior compile the scanner objects directly
from the dependency products.

## Query text provenance

The bundled query resources under
`Sources/TreeSitterStandardLanguages/Queries/` are byte-identical extractions
of RepoPrompt's shipping query strings. Several of those queries were
originally derived from the corresponding grammar repositories' published
`queries/highlights.scm` files (e.g. the PHP highlight query is based on
tree-sitter-php's `highlights.scm`); the grammar license copies in
[`ThirdPartyLicenses/tree-sitter/`](ThirdPartyLicenses/tree-sitter/) cover
that material.
