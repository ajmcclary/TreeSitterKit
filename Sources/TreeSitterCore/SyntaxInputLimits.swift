import Foundation

/// Why a piece of content was refused for tree-sitter parsing.
///
/// The associated `actual` values report the measured size; `limit` reports
/// the threshold that was exceeded.
public enum SyntaxOversizeReason: Hashable, Sendable, CustomStringConvertible {
    case lineCountExceeded(actual: Int, limit: Int)
    case utf16LengthExceeded(actual: Int, limit: Int)
    case utf8SizeExceeded(actual: Int, limit: Int)

    public var description: String {
        switch self {
        case .lineCountExceeded(let actual, let limit):
            return "line count \(actual) exceeded limit \(limit)"
        case .utf16LengthExceeded(let actual, let limit):
            return "UTF-16 length \(actual) exceeded limit \(limit)"
        case .utf8SizeExceeded(let actual, let limit):
            return "UTF-8 size \(actual) exceeded limit \(limit)"
        }
    }
}

/// Large-file safety thresholds guarding tree-sitter parsing.
///
/// ``standard`` reproduces RepoPrompt's `SyntaxManager` limits exactly
/// (`parseLineLimit` 25 000, `parseUTF16Limit` 1 500 000, `parseUTF8Limit`
/// 5 000 000, plus the separate 5 000-line early bail applied only to
/// highlighting).
public struct SyntaxInputLimits: Hashable, Sendable {
    /// Maximum number of lines (`\n`, `\r`, and `\r\n` all count as one line
    /// break) before parsing is refused.
    public var maxLineCount: Int

    /// Maximum content length in UTF-16 code units before parsing is refused.
    public var maxUTF16Length: Int

    /// Maximum content size in UTF-8 bytes before parsing is refused.
    public var maxUTF8ByteCount: Int

    /// Line count above which ``SyntaxParser/captures(in:language:)`` returns
    /// an empty result without parsing (a cheaper, stricter guard applied to
    /// highlighting only -- code-map extraction is not subject to it).
    public var highlightMaxLineCount: Int

    /// RepoPrompt's shipping thresholds.
    public static let standard = SyntaxInputLimits(
        maxLineCount: 25_000,
        maxUTF16Length: 1_500_000,
        maxUTF8ByteCount: 5_000_000,
        highlightMaxLineCount: 5_000
    )

    /// Creates a custom set of limits.
    public init(
        maxLineCount: Int,
        maxUTF16Length: Int,
        maxUTF8ByteCount: Int,
        highlightMaxLineCount: Int
    ) {
        self.maxLineCount = maxLineCount
        self.maxUTF16Length = maxUTF16Length
        self.maxUTF8ByteCount = maxUTF8ByteCount
        self.highlightMaxLineCount = highlightMaxLineCount
    }

    /// Returns a reason if the provided content should skip tree-sitter
    /// parsing, or `nil` when the content is within all limits.
    ///
    /// Checks are ordered exactly as RepoPrompt's implementation: UTF-8 byte
    /// size first, then UTF-16 length, then line count.
    public func oversizeReason(for content: String) -> SyntaxOversizeReason? {
        let utf8View = content.utf8

        // 1) Fast-path: UTF-8 byte size (O(1) when contiguous, otherwise fallback)
        if let byteCount = utf8View.withContiguousStorageIfAvailable({ $0.count }) {
            if byteCount > maxUTF8ByteCount {
                return .utf8SizeExceeded(actual: byteCount, limit: maxUTF8ByteCount)
            }
        } else {
            let utf8Size = utf8View.count
            if utf8Size > maxUTF8ByteCount {
                return .utf8SizeExceeded(actual: utf8Size, limit: maxUTF8ByteCount)
            }
        }

        // 2) UTF-16 code units (only if we didn't already exceed UTF-8 bytes)
        let utf16Length = content.utf16.count
        if utf16Length > maxUTF16Length {
            return .utf16LengthExceeded(actual: utf16Length, limit: maxUTF16Length)
        }

        // 3) Line count (early exit when crossing the threshold)
        if let actualLines = Self.exceededLineCount(in: utf8View, limit: maxLineCount) {
            return .lineCountExceeded(actual: actualLines, limit: maxLineCount)
        }
        return nil
    }

    /// Returns the (limit-exceeding) line count if `utf8` contains more than
    /// `limit` lines, else `nil`. Treats `\n`, `\r`, and `\r\n` each as a
    /// single line break.
    static func exceededLineCount(in utf8: String.UTF8View, limit: Int) -> Int? {
        guard limit > 0 else { return nil }
        guard !utf8.isEmpty else { return nil }

        // Fast path: contiguous UTF-8 buffer scanning (no indexing overhead)
        if let res = utf8.withContiguousStorageIfAvailable({ (buf: UnsafeBufferPointer<UInt8>) -> Int? in
            var lines = 1
            var i = buf.startIndex
            let end = buf.endIndex

            while i < end {
                let b = buf[i]
                if b == 0x0A { // \n
                    lines += 1
                    if lines > limit { return lines }
                    i = buf.index(after: i)
                    continue
                } else if b == 0x0D { // \r
                    lines += 1
                    if lines > limit { return lines }
                    i = buf.index(after: i)
                    if i < end, buf[i] == 0x0A { // swallow \r\n
                        i = buf.index(after: i)
                    }
                    continue
                }
                i = buf.index(after: i)
            }
            return nil
        }) {
            if let exceeded = res { return exceeded }
            return nil
        }

        // Fallback: safe index-based scan
        var lines = 1
        var index = utf8.startIndex
        while index < utf8.endIndex {
            let byte = utf8[index]
            if byte == 0x0A { // \n
                lines += 1
                if lines > limit { return lines }
                index = utf8.index(after: index)
                continue
            } else if byte == 0x0D { // \r
                lines += 1
                if lines > limit { return lines }
                let next = utf8.index(after: index)
                if next < utf8.endIndex, utf8[next] == 0x0A {
                    index = utf8.index(after: next)
                } else {
                    index = next
                }
                continue
            }
            index = utf8.index(after: index)
        }
        return nil
    }
}
