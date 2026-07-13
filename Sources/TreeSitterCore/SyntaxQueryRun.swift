import Foundation

/// A capture produced by ``SyntaxParser/runQuery(_:on:language:)``, including
/// a short text preview of the captured source (useful in tests and query
/// debugging tools).
public struct SyntaxQueryRunCapture: Hashable, Sendable {
    /// The capture name from the query (without the leading `@`).
    public let name: String

    /// The captured node's range in UTF-16 code units of the parsed string.
    public let range: NSRange

    /// The captured text, newline/tab-escaped and truncated to 80 characters.
    public let textPreview: String

    /// Creates a capture value.
    public init(name: String, range: NSRange, textPreview: String) {
        self.name = name
        self.range = range
        self.textPreview = textPreview
    }
}

/// The result of running an ad-hoc query over a source string.
public struct SyntaxQueryRun: Hashable, Sendable {
    /// The parse tree's root node type.
    public let rootNodeType: String?

    /// All captures across all matches, in match order.
    public let captures: [SyntaxQueryRunCapture]

    /// The number of query matches.
    public let matchCount: Int

    /// Creates a result value.
    public init(rootNodeType: String?, captures: [SyntaxQueryRunCapture], matchCount: Int) {
        self.rootNodeType = rootNodeType
        self.captures = captures
        self.matchCount = matchCount
    }
}
