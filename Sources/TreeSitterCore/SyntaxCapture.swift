import Foundation
import LanguageKit

/// A single named query capture over a source string.
///
/// `name` is the tree-sitter capture name without the leading `@` (e.g.
/// `"keyword"`, `"function.builtin"`, `"definition.method"`). `range` is an
/// `NSRange` in **UTF-16 code units** of the source string the capture was
/// produced from -- directly usable with `NSAttributedString`,
/// `NSString`-based APIs, and `Range(_:in:)` bridging back to `String.Index`.
public struct SyntaxCapture: Hashable, Sendable {
    /// The capture name from the query (without the leading `@`).
    public let name: String

    /// The captured node's range in UTF-16 code units of the parsed string.
    public let range: NSRange

    /// Creates a capture value.
    ///
    /// - Parameters:
    ///   - name: The capture name from the query (without the leading `@`).
    ///   - range: The captured range in UTF-16 code units.
    public init(name: String, range: NSRange) {
        self.name = name
        self.range = range
    }
}

/// A safe, value-only summary of a parse, without exposing any tree-sitter
/// tree or node wrapper.
public struct SyntaxTreeSummary: Hashable, Sendable {
    /// The language the content was parsed as.
    public let language: LanguageID

    /// The root node's type name (e.g. `"source_file"`), if a root exists.
    public let rootNodeType: String?

    /// Whether parsing produced a root node.
    public let hasRootNode: Bool

    /// Creates a summary value.
    public init(language: LanguageID, rootNodeType: String?, hasRootNode: Bool) {
        self.language = language
        self.rootNodeType = rootNodeType
        self.hasRootNode = hasRootNode
    }
}
