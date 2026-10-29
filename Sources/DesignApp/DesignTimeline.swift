// DesignTimeline.swift: the timeline slot under Design's canvas (one-document OD-12), from SuiteUI's timeline
// family: a header row with the TransportCapsule and a collapse button, then a TimelineStrip with one lane per
// keyed layer (DesignWorkspace.timelineRows). DesignEditor shows it only while the document has keys
// (`showsTimeline`), sliding it in from the bottom on the first key. Collapsed or open is the user's and stays
// (SceneStorage). Values in, intents out: a scrub, step or end sends `.scrub`, play and loop their intents, a lane
// name or key press selects that layer. A scrub's frame shows at once from the live drag box's `playingFrame`;
// while playing, the slot reads only `isPlaying`, so a tick runs the canvas alone and the slot catches up on pause. Content, not chrome: no glass.
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
                DesignTransportAdapter(model: model, perform: perform)
                Spacer()
                let title = collapsed ? "Show Timeline" : "Hide Timeline"
                Button(title, systemImage: collapsed ? "chevron.up" : "chevron.down") { collapsed.toggle() }
                    .labelStyle(.iconOnly).buttonStyle(.borderless).help(title)
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

/// The transport and its timecode. Like the lanes it reads only `isPlaying` while playing, so a tick runs the
/// canvas alone; the timecode shows the playhead and catches up on pause.
private struct DesignTransportAdapter: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live

    var body: some View {
        let last = model.timelineLastFrame
        // ponytail: a ticking timecode cost ~1.5 ms a frame (QB-L4 went red); a Text-only leaf for it is the upgrade.
        let frame = (live?.isPlaying == true ? nil : live?.playingFrame) ?? model.playhead ?? 0
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
                tracks: tracks, duration: last, frameWidth: Self.laneWidth(proxy.size.width) / CGFloat(max(last, 1)),
                playhead: frame, rate: model.time.rate,
                onScrub: { perform(.scrub($0)) },
                onSelectKeyframe: { id, _ in perform(.select(id)) },
                onSelectTrack: { perform(.select($0)) })
                .environment(\.timelineIdentifierPrefix, "design.timeline")
        }
        .frame(height: height)
    }

    /// The lanes' width in a strip `width` wide: past the name column and its hairline, with Flare's trailing room.
    nonisolated static func laneWidth(_ width: CGFloat) -> CGFloat {
        max(width - SuiteSize.timelineLabelColumn - 1 - SuiteSpacing.xl, 1)
    }
}
