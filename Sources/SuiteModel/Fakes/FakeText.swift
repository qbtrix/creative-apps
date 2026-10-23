// FakeText.swift: the in-memory TextServices (shell-text ST-1, ST-6).
// Measures by fixed advances, the numbers creative-core's `FixedAdvances`
// gives: 0.5 em per grapheme plus the span's tracking after each grapheme,
// ascent 0.8 em, descent 0.2 em, so a Model test that lays out with the fake
// matches core's own tests. Lists three families, and draws a clear frame
// while recording the spans. Spans pass `TextRules` first, as live ones do.
// With `unavailable:` set, measuring and drawing throw
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
        var metrics: [SpanMetrics] = []
        for asked in spans {
            let span = try TextRules.validated(asked)
            let advance = span.fontSize * 0.5 + span.tracking
            metrics.append(SpanMetrics(advances: Array(repeating: advance, count: span.string.count),
                                       ascent: span.fontSize * 0.8, descent: span.fontSize * 0.2,
                                       resolvedFamily: names.contains(span.fontFamily) ? span.fontFamily : Self.systemFamily))
        }
        return metrics
    }

    public func families() -> [FontFamily] { unavailable == nil ? Self.catalog : [] }

    public func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame {
        if let unavailable { throw .notAvailable(unavailable) }
        let pixels = width.multipliedReportingOverflow(by: height)
        let bytes = pixels.partialValue.multipliedReportingOverflow(by: 4)
        guard width > 0, height > 0, !pixels.overflow, !bytes.overflow, bytes.partialValue <= 1 << 30 else {
            throw .notAvailable("A \(width) by \(height) frame is too big to draw text into.")
        }
        for placed in spans { _ = try TextRules.validated(placed) }
        let frame = try MediaFrame(width: width, height: height, rgba: Array(repeating: 0, count: bytes.partialValue))
        log.withLock { $0.append(contentsOf: spans) }
        return frame
    }
}
