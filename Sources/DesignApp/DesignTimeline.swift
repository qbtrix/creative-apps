// DesignTimeline.swift: the timeline slot under Design's canvas (one-document OD-12), from SuiteUI's timeline
// family: a header row with the TransportCapsule and a collapse button, then a TimelineStrip with one lane per
// keyed layer (DesignWorkspace.timelineRows). DesignEditor shows it only while the document has keys
// (`showsTimeline`), sliding it in from the bottom on the first key. Collapsed or open is the user's and stays
// (SceneStorage). Values in, intents out: a scrub, step or end sends `.scrub`, play and loop their intents, a lane
// name or key press selects that layer. The lanes' playhead follows the live drag box's `playingFrame` while
// playing, then `landingFrame` (a scrub's frame, or play once's last frame, until it lands as the playhead); the
// strip redraws only its playhead layer on a tick (#6090). The transport reads `isPlaying` for its Play/Pause
// glyph and never the playing frame. Content, not chrome: no glass.
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

/// The transport and its timecode. It reads `isPlaying` for its glyph and never the playing frame, so a tick
/// runs the canvas alone; the timecode shows the playhead, or a frame about to land, and catches up on pause.
private struct DesignTransportAdapter: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live

    var body: some View {
        let last = model.timelineLastFrame
        // ponytail: a ticking timecode cost ~1.5 ms a frame (QB-L4 went red); a Text-only leaf for it is the upgrade.
        let frame = live?.landingFrame ?? model.playhead ?? 0
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

/// The lanes. This body reads no frame, so a tick never re-walks `timelineRows` (500 rows cost ~5 ms a tick);
/// DesignTimelineStrip, inside it, reads the frame and runs once a tick on the same tracks.
private struct DesignTimelineLanes: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        let rows = model.timelineRows
        let tracks = rows.map { row in
            TimelineTrack(id: row.id, name: row.name, keys: row.keys.map { TimelineKey(frame: $0.frame, shape: TimelineKeyShape(rawValue: $0.shape.rawValue) ?? .linear) },
                          isSelected: model.selectedNodeIDs.contains(row.id))
        }
        // ponytail: lanes cap at five rows tall and scroll past that; a drag-to-size divider is a follow-up.
        let height = SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(min(max(rows.count, 1), 5))
        return GeometryReader { proxy in
            DesignTimelineStrip(model: model, perform: perform, tracks: tracks, width: proxy.size.width)
        }
        .frame(height: height)
    }

    /// The lanes' width in a strip `width` wide: past the name column and its hairline, with Flare's trailing room.
    nonisolated static func laneWidth(_ width: CGFloat) -> CGFloat {
        max(width - SuiteSize.timelineLabelColumn - 1 - SuiteSpacing.xl, 1)
    }
}

/// The strip, reading the frame: the playing frame while playing, then `landingFrame` (a scrub's frame, or play
/// once's last frame, until it lands), then the playhead. A tick runs this body and the strip's playhead layer;
/// the strip's lane rows compare equal on the same tracks and never re-run (#6090).
private struct DesignTimelineStrip: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    let tracks: [TimelineTrack<String>]
    let width: CGFloat
    @Environment(\.designLiveDrag) private var live

    var body: some View {
        let last = model.timelineLastFrame
        let frame = live?.playingFrame ?? live?.landingFrame ?? model.playhead ?? 0
        return TimelineStrip(
            tracks: tracks, duration: last, frameWidth: DesignTimelineLanes.laneWidth(width) / CGFloat(max(last, 1)),
            playhead: frame, rate: model.time.rate,
            onScrub: { perform(.scrub($0)) },
            onSelectKeyframe: { id, _ in perform(.select(id)) },
            onSelectTrack: { perform(.select($0)) })
            .environment(\.timelineIdentifierPrefix, "design.timeline")
    }
}
