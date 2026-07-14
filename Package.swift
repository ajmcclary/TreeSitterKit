// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency")
]

/// Builds a vendored tree-sitter grammar C target.
///
/// Every vendored grammar lives at `Sources/Grammars/<name>/` with the same
/// on-disk shape: `src/parser.c` (+ `src/scanner.c` when the grammar has an
/// external scanner), the private `src/tree_sitter/*.h` headers reached via a
/// `src` header search path, and the public binding header under `include/`.
/// The preserved upstream `LICENSE` is excluded from compilation.
func vendoredGrammar(_ name: String, scanner: Bool = true) -> Target {
    var sources = ["src/parser.c"]
    if scanner { sources.append("src/scanner.c") }
    return .target(
        name: name,
        path: "Sources/Grammars/\(name)",
        exclude: ["LICENSE"],
        sources: sources,
        publicHeadersPath: "include",
        cSettings: [.headerSearchPath("src")]
    )
}

let package = Package(
    name: "TreeSitterKit",
    // Floor: SwiftTreeSitter 0.8.0 and the grammar packages declare no
    // meaningful platform floor (see docs/architecture/platform-matrix.md in
    // the CodeEditor superproject); the binding floor is TreeSitterKit's own
    // use of Swift concurrency (actor), which requires these OS versions.
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "TreeSitterCore", targets: ["TreeSitterCore"]),
        .library(name: "TreeSitterStandardLanguages", targets: ["TreeSitterStandardLanguages"]),
        .library(name: "TreeSitterGrammarAuthoring", targets: ["TreeSitterGrammarAuthoring"]),
        .library(name: "TreeSitterStandardLanguagesAuthoring", targets: ["TreeSitterStandardLanguagesAuthoring"]),
        .library(name: "TreeSitterDiagnostics", targets: ["TreeSitterDiagnostics"]),
        .library(name: "TreeSitterTestSupport", targets: ["TreeSitterTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ajmcclary/LanguageKit.git", .upToNextMinor(from: "0.1.0")),
        // Pinned exactly as RepoPrompt pins it (the proven implementation this
        // package was extracted from). Upgrading to the maintained
        // tree-sitter/swift-tree-sitter upstream is a deliberate, separate change.
        // `exact:` is a version requirement — it does NOT prevent this package
        // from being consumed `from:` a semantic version.
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", exact: "0.8.0"),
        // The 14 standard grammars are VENDORED (their generated C parser and
        // scanner sources live under Sources/Grammars/, one C target per
        // grammar product) at the exact upstream revisions recorded in
        // Sources/Grammars/VENDORED.md. There are therefore NO revision- or
        // branch-pinned dependencies here, which is what makes TreeSitterKit
        // semver-consumable. Re-vendoring is a deliberate act — see
        // Sources/Grammars/VENDORED.md for the procedure.
    ],
    targets: [
        .target(
            name: "TreeSitterCore",
            dependencies: [
                .product(name: "LanguageKit", package: "LanguageKit"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ],
            swiftSettings: swiftSettings
        ),
        // Vendored grammar C targets. Each mirrors exactly what the upstream
        // grammar SwiftPM package compiled: the generated `src/parser.c` (and
        // `src/scanner.c` external scanner where the grammar has one), the
        // private `src/tree_sitter/*.h` headers, and the public Swift binding
        // header declaring `tree_sitter_<lang>()`. Sources are byte-identical
        // to the pinned upstream revisions in Sources/Grammars/VENDORED.md.
        // The JavaScript and Python scanners are now carried here (once, in
        // their real targets), which is why the old TreeSitterKitScannerSupport
        // shim is gone. `exclude: ["LICENSE"]` keeps SwiftPM from flagging the
        // preserved upstream license as an unhandled resource.
        vendoredGrammar("TreeSitterC", scanner: false),
        vendoredGrammar("TreeSitterCSharp"),
        vendoredGrammar("TreeSitterCPP"),
        vendoredGrammar("TreeSitterDart"),
        vendoredGrammar("TreeSitterGo", scanner: false),
        vendoredGrammar("TreeSitterJava", scanner: false),
        vendoredGrammar("TreeSitterJavaScript"),
        vendoredGrammar("TreeSitterPHP"),
        vendoredGrammar("TreeSitterPython"),
        vendoredGrammar("TreeSitterRuby"),
        vendoredGrammar("TreeSitterRust"),
        vendoredGrammar("TreeSitterSwift"),
        // TypeScript and TSX keep their upstream nested layout because their
        // `scanner.c` includes `../../common/scanner.h` (a scanner shared by
        // both grammars). Preserving `<lang>/src/` + a sibling `common/` lets
        // that relative include resolve with no source edit.
        .target(
            name: "TreeSitterTypeScript",
            path: "Sources/Grammars/TreeSitterTypeScript",
            exclude: ["LICENSE"],
            sources: ["typescript/src/parser.c", "typescript/src/scanner.c"],
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("typescript/src")]
        ),
        .target(
            name: "TreeSitterTSX",
            path: "Sources/Grammars/TreeSitterTSX",
            exclude: ["LICENSE"],
            sources: ["tsx/src/parser.c", "tsx/src/scanner.c"],
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("tsx/src")]
        ),
        .target(
            name: "TreeSitterStandardLanguages",
            dependencies: [
                "TreeSitterCore",
                .product(name: "LanguageKit", package: "LanguageKit"),
                "TreeSitterC",
                "TreeSitterCSharp",
                "TreeSitterCPP",
                "TreeSitterDart",
                "TreeSitterGo",
                "TreeSitterJava",
                "TreeSitterJavaScript",
                "TreeSitterPHP",
                "TreeSitterPython",
                "TreeSitterRuby",
                "TreeSitterRust",
                "TreeSitterSwift",
                "TreeSitterTypeScript",
                "TreeSitterTSX",
            ],
            resources: [
                .copy("Queries")
            ],
            swiftSettings: swiftSettings
        ),
        // Ad-hoc query compilation/execution and parse-tree inspection
        // (RepoPrompt's debug tools). Kept out of TreeSitterCore's stable
        // surface; reaches Core's grammar/parse primitives via
        // `@_spi(Diagnostics)`. Imports SwiftTreeSitter, but exposes no
        // SwiftTreeSitter type publicly.
        .target(
            name: "TreeSitterDiagnostics",
            dependencies: [
                "TreeSitterCore",
                .product(name: "LanguageKit", package: "LanguageKit"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ],
            swiftSettings: swiftSettings
        ),
        // The public custom-grammar-authoring path: constructing custom-language
        // registrations (raw grammar-pointer closures). Reaches only the
        // `@_spi(GrammarAuthoring)` surface of Core, so it depends on
        // TreeSitterCore ALONE — importing this product does NOT resolve or link
        // the 14 standard grammars. The standard languages' authoring accessors
        // live in TreeSitterStandardLanguagesAuthoring.
        .target(
            name: "TreeSitterGrammarAuthoring",
            dependencies: [
                "TreeSitterCore",
                .product(name: "LanguageKit", package: "LanguageKit"),
            ],
            swiftSettings: swiftSettings
        ),
        // The public standard-languages authoring path: reading the 14 standard
        // languages' raw registrations and bundled `.scm` query sources. Links
        // TreeSitterStandardLanguages (and therefore the bundled grammars) and
        // reaches the `@_spi(GrammarAuthoring)` surface of Core and
        // StandardLanguages. Kept separate from TreeSitterGrammarAuthoring so
        // custom-grammar authors do not pull in every bundled grammar.
        .target(
            name: "TreeSitterStandardLanguagesAuthoring",
            dependencies: [
                "TreeSitterCore",
                "TreeSitterStandardLanguages",
                .product(name: "LanguageKit", package: "LanguageKit"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "TreeSitterTestSupport",
            dependencies: [
                "TreeSitterCore",
                .product(name: "LanguageKit", package: "LanguageKit"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "TreeSitterKitTests",
            dependencies: [
                "TreeSitterCore",
                "TreeSitterStandardLanguages",
                "TreeSitterGrammarAuthoring",
                "TreeSitterStandardLanguagesAuthoring",
                "TreeSitterDiagnostics",
                "TreeSitterTestSupport",
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
