// DesignTimeline.swift: the timeline slot under Design's canvas (one-document OD-12), from SuiteUI's timeline
// family: a header row with the TransportCapsule and a collapse button, then a TimelineStrip with one lane per
// keyed layer (DesignWorkspace.timelineRows). DesignEditor shows it only while the document has keys
// (`showsTimeline`), sliding it in from the bottom on the first key. Collapsed or open is the user's and stays
// (SceneStorage). Values in, intents out: a scrub, step or end sends `.scrub`, play and loop their intents, a lane
// name or key press selects that layer. The frame shown reads the live drag box's `playingFrame` (playback and a
// scrub in flight) in this leaf, beside the canvas, so neither runs the window. Content, not chrome: no glass.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignTimeline: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live
    @SceneStorage("design.timeline.collapsed") private var collapsed = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: SuiteSpacing.s) {
                DesignTimelineTransport(model: model, perform: perform)
                Spacer()
                Button(collapsed ? "Show Timeline" : "Hide Timeline",
                       systemImage: collapsed ? "chevron.up" : "chevron.down") { collapsed.toggle() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help(collapsed ? "Show Timeline" : "Hide Timeline")
                    .accessibilityIdentifier("design.timeline.collapse")
            }
            .padding(.horizontal, SuiteSpacing.s)
            .padding(.vertical, SuiteSpacing.xs)
            if !collapsed { DesignTimelineLanes(model: model, perform: perform) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("design.timeline")
    }
}

/// The transport and its timecode: the one part of the slot that follows every playback frame.
private struct DesignTimelineTransport: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live

    var body: some View {
        let last = model.timelineLastFrame
        let frame = live?.playingFrame ?? model.playhead ?? 0
        TransportCapsule(
                    state: TransportState(frame: frame, frameCount: last + 1, fps: model.time.rate.nominal,
                                          isPlaying: live?.isPlaying ?? false,
                                          loops: live?.playLoops ?? false),
                    onPlay: { perform(.playPause) },
                    onStep: { perform(.scrub(min(max(frame + $0, 0), last))) },
                    onStart: { perform(.scrub(0)) }, onEnd: { perform(.scrub(last)) },
                    onLoop: { perform(.loop($0)) })
    }
}

/// The lanes. While playing they read only `isPlaying`, never the frame, so a tick doesn't rebuild 500 lanes:
/// the strip's playhead parks at the playhead and catches up on pause. A scrub's frame shows at once.
private struct DesignTimelineLanes: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live

    var body: some View {
        let last = model.timelineLastFrame, rows = model.timelineRows
        // ponytail: the strip's playhead parks during play; a playhead-only overlay leaf in TimelineStrip would let it follow.
        let frame = (live?.isPlaying == true ? nil : live?.playingFrame) ?? model.playhead ?? 0
        let tracks = rows.map { row in
            TimelineTrack(id: row.id, name: row.name, keys: row.keys.map { TimelineKey(frame: $0.frame, shape: TimelineKeyShape(rawValue: $0.shape.rawValue) ?? .linear) },
                          isSelected: model.selectedNodeIDs.contains(row.id))
        }
        // ponytail: lanes cap at five rows tall and scroll past that; a drag-to-size divider is a follow-up.
        let height = SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(min(max(rows.count, 1), 5))
        return GeometryReader { proxy in
            TimelineStrip(
                tracks: tracks, duration: last, frameWidth: max(proxy.size.width - 160, 1) / CGFloat(max(last, 1)),
                playhead: frame, rate: model.time.rate,
                onScrub: { perform(.scrub($0)) },
                onSelectKeyframe: { id, _ in perform(.select(id)) },
                onSelectTrack: { perform(.select($0)) })
                .environment(\.timelineIdentifierPrefix, "design.timeline")
        }
        .frame(height: height)
    }
}
