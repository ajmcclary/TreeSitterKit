# Third-Party Notices

## Tree-sitter grammars (vendored) and runtime

TreeSitterKit **vendors** thirteen Tree-sitter grammar packages' generated C
sources (parser and, where present, external scanner) directly into
[`Sources/Grammars/`](Sources/Grammars/), each at a fixed upstream revision, and
links the `SwiftTreeSitter` wrapper (with its embedded Tree-sitter C runtime)
through a single `exact: "0.8.0"` version pin. The vendored grammar sources and
the `SwiftTreeSitter` package both require attribution when distributed.

[`Sources/Grammars/VENDORED.md`](Sources/Grammars/VENDORED.md) is the provenance
manifest: it maps each vendored target to its upstream repository, exact
revision, and license, records that every vendored file is byte-identical to the
pinned upstream source (checksums in
[`Sources/Grammars/VENDORED.sha256`](Sources/Grammars/VENDORED.sha256)), and
documents the deliberate re-vendoring procedure. Each grammar's upstream
`LICENSE` is preserved both next to its vendored sources
(`Sources/Grammars/<Module>/LICENSE`) and in the curated
[`ThirdPartyLicenses/tree-sitter/`](ThirdPartyLicenses/tree-sitter/) collection,
which also holds the `SwiftTreeSitter` wrapper, its embedded Tree-sitter runtime,
and the ICU subset notice shipped with that runtime.

## JavaScript and Python external scanners

Earlier revisions of this package carried a separate
`TreeSitterKitScannerSupport` C target with copies of only the JavaScript and
Python external scanners, because clean SwiftPM resolutions of those two
*grammar packages* dropped their scanner objects (their manifests probed
`src/scanner.c` with a cwd-relative `FileManager` check that failed during
manifest evaluation). Now that the grammars are vendored, each grammar's real
`src/scanner.c` is compiled exactly once inside its own target
(`Sources/Grammars/TreeSitterJavaScript/src/scanner.c`,
`Sources/Grammars/TreeSitterPython/src/scanner.c`, and so on), so the shim and
its checksum file are gone. There is exactly one definition of each
`tree_sitter_<lang>_external_scanner_*` symbol.

## Query text provenance

The bundled query resources under
`Sources/TreeSitterStandardLanguages/Queries/` are byte-identical extractions
of RepoPrompt's shipping query strings. Several of those queries were
originally derived from the corresponding grammar repositories' published
`queries/highlights.scm` files (e.g. the PHP highlight query is based on
tree-sitter-php's `highlights.scm`); the grammar license copies in
[`ThirdPartyLicenses/tree-sitter/`](ThirdPartyLicenses/tree-sitter/) and
[`Sources/Grammars/`](Sources/Grammars/) cover that material.
