# Changelog

All notable changes to TreeSitterKit are documented here. This project adheres
to [Semantic Versioning](https://semver.org).

## 0.2.0

### Changed

- **Vendored all 14 standard-language grammars.** The 13 tree-sitter grammar
  SwiftPM packages that were previously revision-pinned dependencies (C, C#,
  C++, Dart, Go, Java, JavaScript, PHP, Python, Ruby, Rust, Swift, and
  TypeScript — the last providing both TypeScript and TSX) are now vendored
  directly under `Sources/Grammars/`, one C target per grammar, at the same
  exact upstream revisions. Every vendored file is byte-identical to its pinned
  upstream source (no edits, not even include paths); provenance, checksums, and
  the re-vendoring procedure are in `Sources/Grammars/VENDORED.md`. Parse,
  highlight, and code-map behavior is unchanged.
- **TreeSitterKit is now semver-consumable.** With no revision- or branch-pinned
  dependencies remaining (only `LanguageKit` and `SwiftTreeSitter@exact 0.8.0`,
  both version requirements), consumers can depend on it `from: "0.2.0"` instead
  of pinning a revision.

### Removed

- **`TreeSitterKitScannerSupport` target.** It existed only to supply the
  JavaScript and Python external scanners that clean SwiftPM resolutions of
  those grammar *packages* dropped. Each grammar's real `src/scanner.c` is now
  compiled once inside its own vendored target, so the shim and its
  `scanner-support.sha256` checksum file are gone. Each
  `tree_sitter_<lang>_external_scanner_*` symbol is defined exactly once.

### Notes

- Public API is unchanged: the same six products, the same `SyntaxParser`
  surface, and the same 14 languages via `SyntaxParser.standard()`.
