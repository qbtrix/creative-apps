// TimelinePlayhead.swift: the playhead, one layer TimelineStrip lays over its
// ruler and lanes (timeline packet, TL-8). A 2 pt accent line at the current
// frame's tick; the time pill (TimelineTime.label in accentFill, white
// SuiteFont.pill text) placed by TimelineLook.pillRect on the ruler, over a
// 2 pt ground knock-out so the ruler never draws for the playhead (#1257);
// the keys at the playhead on the visible rows in stateKeyed, so no lane
// redraws for it either. The pill and a 16 pt band down the line grab it
// (TimelinePlayheadGrab); a drag scrubs through TimelineScrubSender, which
// the ruler's drag uses too and which calls onScrub only when the frame
// changes (#1297). Equatable without its closure, so the strip skips it
// unless the playhead, the scroll or the keyed rows change.
import SwiftUI

struct TimelinePlayhead: View {
    let mapping: FrameMapping
    let playhead: Int
    let unit: TimeUnit
    let fps: Int
    /// The content x at the layer's leading edge and the lanes' scrolled y.
    let scroll: CGPoint
    /// The keys at the playhead on the rows in view.
    let keys: [TimelinePlayheadKey]
    let onScrub: @MainActor (Int) -> Void
    @State private var sender = TimelineScrubSender()

    #if DEBUG
    /// How many times a playhead's body ran; the real-window budget tests count a scrub's.
    static var bodyRuns = 0
    #endif

    /// What the pill reads: the playhead in the host's unit.
    var label: String { TimelineTime.label(frame: mapping.clamp(playhead), fps: fps, unit: unit) }

    var body: some View {
        #if DEBUG
        Self.bodyRuns += 1
        #endif
        return GeometryReader { proxy in
            let lineX = tickX(mapping, mapping.clamp(playhead)) - scroll.x
            let pill = TimelinePlayheadGrab.pill(lineX: lineX, label: label, width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in draw(lineX: lineX, pill: pill, size: size, in: &context) }
                Text(label)
                    .font(SuiteFont.pill)
                    .foregroundStyle(.white)
                    .frame(width: pill.width, height: pill.height)
                    // A view background, not a color one, so it keeps to the safe area (#1034).
                    .background(alignment: .center) { Capsule().fill(SuiteColor.accentFill) }
                    .offset(x: pill.minX, y: pill.minY)
            }
            .contentShape(TimelinePlayheadGrab.shape(lineX: lineX, pill: pill, height: proxy.size.height))
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let frame = mapping.frame(atX: Double(drag.location.x + scroll.x - timelineInset))
                sender.send(frame, from: playhead, to: onScrub)
            }.onEnded { _ in sender.end() })
        }
    }

    /// The knock-out, the line, then the keyed keys clipped below the ruler.
    private func draw(lineX: CGFloat, pill: CGRect, size: CGSize, in context: inout GraphicsContext) {
        let out = TimelinePlayheadGrab.knockOut
        let ground = pill.insetBy(dx: -out, dy: -out)
        context.fill(Path(roundedRect: ground, cornerRadius: ground.height / 2), with: .color(SuiteColor.ground))
        let line = TimelinePlayheadGrab.line
        context.fill(Path(CGRect(x: lineX - line / 2, y: 0, width: line, height: size.height)), with: .color(SuiteColor.accent))
        var lanes = context
        let ruler = SuiteSize.timelineRuler
        lanes.clip(to: Path(CGRect(x: 0, y: ruler, width: size.width, height: max(size.height - ruler, 0))))
        for key in keys {
            let y = ruler + SuiteSize.timelineLane * (CGFloat(key.row) + 0.5) - scroll.y
            let shape = TimelineLaneGeometry.keyShape(key.glyph, center: CGPoint(x: lineX, y: y), size: SuiteSize.timelineKeyframe)
            let edge = TimelineLook.keyEdge(picked: key.picked)
            lanes.fill(shape, with: .color(TimelineLook.keyFill(picked: key.picked, atPlayhead: true).color()))
            lanes.stroke(shape, with: .color(edge.color.color()), lineWidth: CGFloat(edge.width))
        }
    }

    /// The keys at `playhead` on `tracks`' rows inside `rows`.
    static func keys<ID>(at playhead: Int, in tracks: [TimelineTrack<ID>], rows: Range<Int>) -> [TimelinePlayheadKey] {
        let rows = rows.clamped(to: tracks.indices)
        return rows.compactMap { row in
            let track = tracks[row]
            guard let key = track.keys.first(where: { $0.frame == playhead }) else { return nil }
            return TimelinePlayheadKey(
                row: row, glyph: TimelineLook.keyPath(key.shape).glyph, picked: track.pickedFrames.contains(playhead))
        }
    }

    /// The rows a lanes' visible y range shows; every row before it reports.
    static func rows(showing visibleY: ClosedRange<Double>?, count: Int) -> Range<Int> {
        guard let visibleY else { return 0..<max(count, 0) }
        let lane = Double(SuiteSize.timelineLane)
        let first = max(Int((visibleY.lowerBound / lane).rounded(.down)), 0)
        let end = max(Int((visibleY.upperBound / lane).rounded(.up)), first)
        return first..<end
    }
}

extension TimelinePlayhead: Equatable {
    /// Compares what the layer draws; the closure is left out.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.mapping == rhs.mapping && lhs.playhead == rhs.playhead && lhs.unit == rhs.unit && lhs.fps == rhs.fps
            && lhs.scroll == rhs.scroll && lhs.keys == rhs.keys
    }
}

/// A key the playhead layer draws keyed: its row, glyph and pick.
struct TimelinePlayheadKey: Equatable, Sendable {
    let row: Int
    let glyph: TimelineLook.KeyGlyph
    let picked: Bool
}

/// Where the playhead draws and takes a press, with no view (TimelinePlayheadTests).
enum TimelinePlayheadGrab {
    /// The band down the line that grabs it: the 16 pt key token.
    static let band: CGFloat = SuiteSize.timelineKeyframeHit
    /// The line's width.
    static let line = SuiteSpacing.xxs
    /// The ground left around the pill on the ruler.
    static let knockOut = SuiteSpacing.xxs
    /// The divider between the names column and the lanes, which the layer starts after.
    static let divider: CGFloat = 1

    /// The pill for `label` on the ruler of a layer `width` wide, centred on `lineX`.
    static func pill(lineX: CGFloat, label: String, width: CGFloat) -> CGRect {
        let rect = TimelineLook.pillRect(
            playheadX: Double(lineX), labelWidth: Double(label.count) * Double(SuiteSize.timelineLabelDigit),
            height: Double(SuiteSize.pill), visible: 0...Double(max(width, 0)))
        return rect.offsetBy(dx: 0, dy: (SuiteSize.timelineRuler - SuiteSize.pill) / 2)
    }

    /// What grabs the playhead: the pill and the band, `height` tall.
    static func shape(lineX: CGFloat, pill: CGRect, height: CGFloat) -> Path {
        var path = Path(CGRect(x: lineX - band / 2, y: 0, width: band, height: max(height, 0)))
        path.addRect(pill)
        return path
    }
}

/// The one scrub sender, for the playhead's drag and the ruler's: it calls
/// onScrub only with a frame other than the last sent (the playhead when a
/// drag begins). A class, so a sample that repeats a frame writes no state.
@MainActor final class TimelineScrubSender {
    private(set) var lastSent: Int?

    /// Sends `frame` unless it is the last frame sent, or `playhead` before any.
    func send(_ frame: Int, from playhead: Int, to onScrub: @MainActor (Int) -> Void) {
        let last = lastSent ?? playhead
        guard frame != last else { return }
        lastSent = frame
        onScrub(frame)
    }

    /// The drag ended; the next one starts from the playhead.
    func end() { lastSent = nil }
}
