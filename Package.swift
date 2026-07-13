// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency")
]

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
        .library(name: "TreeSitterDiagnostics", targets: ["TreeSitterDiagnostics"]),
        .library(name: "TreeSitterTestSupport", targets: ["TreeSitterTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ajmcclary/LanguageKit.git", .upToNextMinor(from: "0.1.0")),
        // Pinned exactly as RepoPrompt pins it (the proven implementation this
        // package was extracted from). Upgrading to the maintained
        // tree-sitter/swift-tree-sitter upstream is a deliberate, separate change.
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", exact: "0.8.0"),
        // Grammar pins are byte-identical to RepoPrompt's project.pbxproj /
        // Package.resolved revisions. Do not upgrade casually: query text and
        // node-type names are grammar-revision-sensitive.
        .package(url: "https://github.com/tree-sitter/tree-sitter-c", revision: "3efee11f784605d44623d7dadd6cd12a0f73ea92"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-c-sharp.git", revision: "b27b091bfdc5f16d0ef76421ea5609c82a57dff0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-cpp", revision: "e5cea0ec884c5c3d2d1e41a741a66ce13da4d945"),
        .package(url: "https://github.com/UserNobody14/tree-sitter-dart", revision: "80e23c07b64494f7e21090bb3450223ef0b192f4"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-go", revision: "c350fa54d38af725c40d061a602ee3205ef1e072"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-java", revision: "e10607b45ff745f5f876bfa3e94fbcc6b44bdc11"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-javascript", revision: "39798e26b6d4dbcee8e522b8db83f8b2df33a5ea"),
        .package(url: "https://github.com/provencher/tree-sitter-php", revision: "0a99deca13c4af1fb9adcb03c958bfc9f4c740a9"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-python", revision: "c5fca1a186e8e528115196178c28eefa8d86b0b0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-ruby", revision: "7a010836b74351855148818d5cb8170dc4df8e6a"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-rust", revision: "2eaf126458a4d6a69401089b6ba78c5e5d6c1ced"),
        .package(url: "https://github.com/alex-pinkus/tree-sitter-swift", revision: "9253825dd2570430b53fa128cbb40cb62498e75d"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-typescript", revision: "75b3874edb2dc714fb1fd77a32013d0f8699989f"),
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
        // Compatibility shim carried over from RepoPrompt: clean SwiftPM
        // resolutions of the exact-pinned JavaScript and Python grammar
        // packages omit their external-scanner objects (their manifests probe
        // `src/scanner.c` with a cwd-relative FileManager check that fails
        // during manifest evaluation), so the required
        // `tree_sitter_<lang>_external_scanner_*` symbols would be undefined
        // at link time. This target compiles copies of only the missing
        // upstream scanner implementations (see THIRD_PARTY_NOTICES.md).
        .target(
            name: "TreeSitterKitScannerSupport",
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("include")]
        ),
        .target(
            name: "TreeSitterStandardLanguages",
            dependencies: [
                "TreeSitterCore",
                "TreeSitterKitScannerSupport",
                .product(name: "LanguageKit", package: "LanguageKit"),
                .product(name: "TreeSitterC", package: "tree-sitter-c"),
                .product(name: "TreeSitterCSharp", package: "tree-sitter-c-sharp"),
                .product(name: "TreeSitterCPP", package: "tree-sitter-cpp"),
                .product(name: "TreeSitterDart", package: "tree-sitter-dart"),
                .product(name: "TreeSitterGo", package: "tree-sitter-go"),
                .product(name: "TreeSitterJava", package: "tree-sitter-java"),
                .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript"),
                .product(name: "TreeSitterPHP", package: "tree-sitter-php"),
                .product(name: "TreeSitterPython", package: "tree-sitter-python"),
                .product(name: "TreeSitterRuby", package: "tree-sitter-ruby"),
                .product(name: "TreeSitterRust", package: "tree-sitter-rust"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
                .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
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
        // The public grammar-authoring path: constructing custom-language
        // registrations (raw grammar-pointer closures) and reading the
        // standard languages' bundled `.scm` query sources. Reaches the
        // `@_spi(GrammarAuthoring)` surface of Core and StandardLanguages.
        .target(
            name: "TreeSitterGrammarAuthoring",
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
                "TreeSitterDiagnostics",
                "TreeSitterTestSupport",
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
