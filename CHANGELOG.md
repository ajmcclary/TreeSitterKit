# Changelog

All notable changes to TreeSitterKit are documented here. This project adheres
to [Semantic Versioning](https://semver.org).

## 0.3.1 — 2026-11-12

This release remediates the 2026-11-12 full review.

### Fixed

- **Highlight and code-map queries now evaluate their predicates.**
  `SyntaxParser.captures(in:language:)` and `codeMapCaptures(in:language:)`
  previously reported every structural match and ignored `#eq?`, `#match?`
  and the other predicates, so (for example) every Swift type name was also
  captured as `variable.builtin` and every Python identifier as `constant`.
  Captures whose predicates fail are now dropped. Consumers that styled or
  indexed by the last capture at a range will see different, correct output.
- **Consumers that pin code-map output must regenerate their expectations.**
  Evaluating predicates changes the capture sets of both the highlight and
  the code-map queries, so golden files of captures or of anything derived
  from them will differ. For example, TypeScript/TSX arrow-function `const`s
  are no longer also captured as `variable.global`, in TSX a `const`
  initialised by a call other than `forwardRef`/`memo` is no longer a
  `function.definition`,
  and Ruby `Foo.new` is no longer an `import`.

### Notes

- Public API is unchanged. Dependencies are unchanged: `LanguageKit`
  `.upToNextMinor(from: "0.2.0")`, `SwiftTreeSitter` `exact: "0.8.0"`.
- `TreeSitterDiagnostics`' ad-hoc `runQuery` still reports raw, unresolved
  matches.
- `0.3.0` (2026-07-25) has no entry of its own: it moved to Swift 6
  per-target settings, a 27.0 floor on all five platforms, and `LanguageKit`
  `.upToNextMinor(from: "0.2.0")`.

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
