// FakeText.swift: the in-memory TextServices (shell-text ST-1). Measures by
// fixed advances (0.5 em per grapheme, ascent 0.8 em, descent 0.2 em; ST-6
// adds tracking), lists three families, and draws a clear frame while
// recording the spans. With `unavailable:` set, measuring and drawing throw
// `.notAvailable(that sentence)` and the list is empty.
import Synchronization

public final class FakeText: TextServices {
    /// The family an empty or unknown family name resolves to.
    public static let systemFamily = "System UI"

    static let catalog: [FontFamily] = [
        FontFamily(name: "Mono", faces: [FontFace(name: "Regular", weight: 400, italic: false)]),
        FontFamily(name: "Serif", faces: [FontFace(name: "Regular", weight: 400, italic: false),
                                          FontFace(name: "Italic", weight: 400, italic: true)]),
        FontFamily(name: systemFamily, faces: [FontFace(name: "Regular", weight: 400, italic: false),
                                               FontFace(name: "Bold", weight: 700, italic: false)]),
    ]

    private let log = Mutex([PlacedSpan]())
    let unavailable: String?

    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// Every span drawn, in order.
    public var drawn: [PlacedSpan] { log.withLock { $0 } }

    public func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics] {
        if let unavailable { throw .notAvailable(unavailable) }
        let names = Set(Self.catalog.map(\.name))
        return spans.map { span in
            SpanMetrics(advances: Array(repeating: span.fontSize * 0.5, count: span.string.count),
                        ascent: span.fontSize * 0.8, descent: span.fontSize * 0.2,
                        resolvedFamily: names.contains(span.fontFamily) ? span.fontFamily : Self.systemFamily)
        }
    }

    public func families() -> [FontFamily] { unavailable == nil ? Self.catalog : [] }

    public func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame {
        if let unavailable { throw .notAvailable(unavailable) }
        let pixels = width.multipliedReportingOverflow(by: height)
        let bytes = pixels.partialValue.multipliedReportingOverflow(by: 4)
        guard width > 0, height > 0, !pixels.overflow, !bytes.overflow, bytes.partialValue <= 1 << 30 else {
            throw .notAvailable("A \(width) by \(height) frame is too big to draw text into.")
        }
        let frame = try MediaFrame(width: width, height: height, rgba: Array(repeating: 0, count: bytes.partialValue))
        log.withLock { $0.append(contentsOf: spans) }
        return frame
    }
}
