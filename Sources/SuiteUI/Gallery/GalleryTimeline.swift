// GalleryTimeline.swift: the gallery's timeline pages. `timeline` is the
// packet's fixture (60 frames at 24 fps, 10 pt per frame, playhead 30; Ball
// with keys in the three shapes, Shadow with two eased keys, Badge with a
// clip 20...50 and keys on it); `timeline-long` is 300 lanes over 10,000
// frames with the toolbar on. The page is the host: it owns the playhead,
// picked keys, unit and work area in @State, applies each strip callback
// (moves through KeyEditing: the live SuiteKeyEditing, or FakeKeyEditing
// under -SuiteGalleryFakes) and writes one line per callback to the
// `suite.gallery.log` element the journeys read (`track ball`, `scrub 18`,
// `pick ball 12 replace`, `pick ball none`, `move +5`, `move end`,
// `trim badge end 40`, `trim end`, `unit timecode`, `work 0…9999`). Three
// page switches (No tracks, Nothing picked, Toolbar) are single-chip
// ChipRows, each its own `suite.gallery.timeline.*` control; the strip
// carries an easing context menu for the picked keys, as a host adds one.
// The page offers the strip the height left between the switches and the log,
// with no vertical ScrollView of its own, so `timeline-long`'s 300 lanes
// scroll under the strip's pinned ruler. The page sets the strip's identifier
// prefix `suite.timeline` (lanes `suite.timeline.lane.<id>`, keys
// `suite.timeline.key.<id>.<frame>`, names `suite.timeline.name.<id>`), and
// publishes Badge's lane value as the label of a hidden 1 x 1 pt element,
// `suite.gallery.timeline.value.badge`, since XCUITest reads SwiftUI values
// as "" (#262; the HaloReadout pattern).
import SwiftUI

enum GalleryTimeline {
    @MainActor static let pages: GalleryPages = [
        "timeline": { AnyView(GalleryTimelinePage(fixture: .short)) },
        "timeline-long": { AnyView(GalleryTimelinePage(fixture: .long)) },
    ]
}

/// What a timeline page starts with.
struct GalleryTimelineFixture {
    let duration: Int
    let fps: Int
    let frameWidth: CGFloat
    let playhead: Int
    let toolbar: Bool
    let order: [String]
    let names: [String: String]
    let keys: [String: [TimelineKey]]
    let spans: [String: [ClosedRange<Int>]]
    let picked: Set<LaneKey>
    let selected: String?

    /// The packet's Screens row for `timeline`.
    static let short = GalleryTimelineFixture(
        duration: 59, fps: 24, frameWidth: 10, playhead: 30, toolbar: false,
        order: ["ball", "shadow", "badge"],
        names: ["ball": "Ball", "shadow": "Shadow", "badge": "Badge"],
        keys: [
            "ball": [
                TimelineKey(frame: 0, shape: .linear), TimelineKey(frame: 12, shape: .eased),
                TimelineKey(frame: 24, shape: .hold), TimelineKey(frame: 36, shape: .linear),
            ],
            "shadow": [TimelineKey(frame: 12, shape: .eased), TimelineKey(frame: 36, shape: .eased)],
            "badge": [20, 30, 50].map { TimelineKey(frame: $0, shape: .linear) },
        ],
        spans: ["badge": [20...50]],
        picked: [LaneKey(track: "ball", frame: 12)], selected: "ball")

    /// 300 lanes over 10,000 frames, a key every 24 frames in turning shapes.
    static let long: GalleryTimelineFixture = {
        let ids = (0..<300).map { "lane-\($0)" }
        let shapes: [TimelineKeyShape] = [.linear, .eased, .hold]
        var names: [String: String] = [:]
        var keys: [String: [TimelineKey]] = [:]
        for (row, id) in ids.enumerated() {
            names[id] = "Lane \(row + 1)"
            keys[id] = stride(from: row % 24, through: 9_999, by: 24).enumerated().map { index, frame in
                TimelineKey(frame: frame, shape: shapes[(index + row) % shapes.count])
            }
        }
        return GalleryTimelineFixture(
            duration: 9_999, fps: 24, frameWidth: 2, playhead: 120, toolbar: true, order: ids, names: names,
            keys: keys, spans: [:], picked: [], selected: nil)
    }()
}

/// One timeline page: the switches, the strip over the page's state, the log.
private struct GalleryTimelinePage: View {
    let fixture: GalleryTimelineFixture
    @Environment(\.galleryRequest) private var request
    @State private var keys: [String: [TimelineKey]]
    @State private var spans: [String: [ClosedRange<Int>]]
    @State private var picked: Set<LaneKey>
    @State private var selected: String?
    @State private var playhead: Int
    @State private var unit: TimeUnit = .frames
    @State private var workArea: ClosedRange<Int>?
    @State private var noTracks = false
    @State private var nothingPicked = false
    @State private var toolbar: Bool
    @State private var log: [String] = []

    init(fixture: GalleryTimelineFixture) {
        self.fixture = fixture
        _keys = State(initialValue: fixture.keys)
        _spans = State(initialValue: fixture.spans)
        _picked = State(initialValue: fixture.picked)
        _selected = State(initialValue: fixture.selected)
        _playhead = State(initialValue: fixture.playhead)
        _toolbar = State(initialValue: fixture.toolbar)
    }

    /// The live key rules, or the contract's Fake under -SuiteGalleryFakes.
    private var keyEditing: any KeyEditing {
        if request?.fakes == true { return FakeKeyEditing() }
        return SuiteKeyEditing()
    }

    private var tracks: [TimelineTrack<String>] {
        guard !noTracks else { return [] }
        return fixture.order.map { id in
            TimelineTrack(
                id: id, name: fixture.names[id] ?? id, keys: keys[id] ?? [], spans: spans[id] ?? [],
                pickedFrames: nothingPicked ? [] : Set(picked.filter { $0.track == id }.map(\.frame)),
                isSelected: id == selected)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(spacing: SuiteSpacing.xs) {
                pageSwitch("No tracks", id: "no-tracks", isOn: noTracks) { noTracks.toggle() }
                pageSwitch("Nothing picked", id: "nothing-picked", isOn: nothingPicked) { nothingPicked.toggle() }
                pageSwitch("Toolbar", id: "toolbar", isOn: toolbar) { toolbar.toggle() }
            }
            // No outer ScrollView: the strip is offered the room between the
            // switches and the log, capped below its ideal height on the long
            // page, so its lanes scroll lazily under the pinned ruler (TL-7).
            // The priority hands it that room ahead of the Spacer.
            strip
                .layoutPriority(1)
            if noTracks {
                Text("No tracks yet.")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: SuiteSize.timelineLane)
            }
            Spacer(minLength: 0)
            logView
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            if let badge = tracks.first(where: { $0.id == "badge" }) {
                GalleryTimelineReadout(
                    identifier: "suite.gallery.timeline.value.badge", text: TimelineLaneSpeech.value(of: badge))
            }
        }
    }

    private var strip: some View {
        TimelineStrip(
            tracks: tracks, duration: fixture.duration, frameWidth: fixture.frameWidth, playhead: playhead,
            unit: unit, fps: fixture.fps, workArea: workArea, toolbar: toolbar,
            onScrub: { frame in
                playhead = frame
                write("scrub \(frame)")
            },
            onSelectKeyframe: { id, _ in selected = id },
            onSelectTrack: { id in
                selected = id
                write("track \(id)")
            },
            onPickKeyframe: { pick($0, $1, $2) },
            onMoveKeyframes: { move($0) },
            onEndKeyDrag: { write("move end") },
            onTrim: { trim($0, $1, $2) },
            onEndTrim: { write("trim end") },
            onUnit: { new in
                unit = new
                write("unit \(new.rawValue)")
            },
            onWorkArea: { range in
                workArea = range
                write(range.map { "work \($0.lowerBound)…\($0.upperBound)" } ?? "work off")
            })
            .contextMenu { easingItems }
            .environment(\.timelineIdentifierPrefix, "suite.timeline")
    }

    /// One page switch: a ChipRow of one chip, so its identifier lands on that chip alone.
    private func pageSwitch(
        _ title: String, id: String, isOn: Bool, toggle: @escaping @MainActor () -> Void
    ) -> some View {
        ChipRow([ChipItem(id: id, title: title, isOn: isOn)]) { _ in toggle() }
            .help(title)
            .suiteControl(id: "suite.gallery.timeline.\(id)", enabled: true, reason: nil)
    }

    /// The easing menu for the picked keys, each item disabled with why while nothing is picked.
    @ViewBuilder private var easingItems: some View {
        let why = picked.isEmpty || nothingPicked ? "Pick a key first." : nil
        ForEach(GalleryEase.allCases, id: \.self) { ease in
            Button(ease.rawValue) { setShape(ease) }
                .disabled(why != nil)
                .help(why ?? ease.rawValue)
        }
    }

    private var logView: some View {
        let text = log.joined(separator: "\n")
        return Text(log.last ?? "Nothing yet")
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .lineLimit(1)
            .accessibilityLabel(text)
            .accessibilityValue(text)
            .accessibilityIdentifier("suite.gallery.log")
    }

    private func write(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }

    private func pick(_ id: String, _ frame: Int?, _ mode: PickMode) {
        guard let frame else {
            picked.removeAll()
            write("pick \(id) none")
            return
        }
        let key = LaneKey(track: id, frame: frame)
        switch mode {
        case .replace: picked = [key]
        case .extend: picked.insert(key)
        case .toggle:
            if picked.remove(key) == nil { picked.insert(key) }
        }
        nothingPicked = false
        write("pick \(id) \(frame) \(mode.rawValue)")
    }

    /// Moves every picked key by `delta` frames through the key rules; a moved
    /// key replaces an unpicked one it lands on.
    private func move(_ delta: Int) {
        let moved = keyEditing.moved(picked, by: delta, lastFrame: fixture.duration)
        var next = keys
        for track in Set(picked.map(\.track)) {
            let landed = Set(moved.filter { $0.key.track == track }.map(\.value))
            next[track] = (keys[track] ?? []).compactMap { key -> TimelineKey? in
                if let frame = moved[LaneKey(track: track, frame: key.frame)] {
                    return TimelineKey(frame: frame, shape: key.shape)
                }
                return landed.contains(key.frame) ? nil : key
            }.sorted { $0.frame < $1.frame }
        }
        keys = next
        picked = Set(moved.map { LaneKey(track: $0.key.track, frame: $0.value) })
        write("move \(delta >= 0 ? "+" : "")\(delta)")
    }

    /// Sets the `edge` of the track's span nearest `frame`, never past its other edge.
    private func trim(_ id: String, _ edge: SpanEdge, _ frame: Int) {
        var list = spans[id] ?? []
        let distance = { (span: ClosedRange<Int>) in abs((edge == .start ? span.lowerBound : span.upperBound) - frame) }
        guard let index = list.indices.min(by: { distance(list[$0]) < distance(list[$1]) }) else { return }
        let span = list[index]
        list[index] = edge == .start
            ? min(frame, span.upperBound)...span.upperBound : span.lowerBound...max(frame, span.lowerBound)
        spans[id] = list
        write("trim \(id) \(edge.rawValue) \(frame)")
    }

    private func setShape(_ ease: GalleryEase) {
        for track in Set(picked.map(\.track)) {
            keys[track] = (keys[track] ?? []).map { key in
                picked.contains(LaneKey(track: track, frame: key.frame)) ? TimelineKey(frame: key.frame, shape: ease.shape) : key
            }
        }
        write("ease \(ease.rawValue.lowercased())")
    }
}

/// A value a journey reads, as the label of a hidden element: 1 x 1 pt, no
/// hits, drawing nothing, so the app audit finds no control or text in it.
private struct GalleryTimelineReadout: View {
    /// Its side: not a design size, since it draws nothing.
    private static let side: CGFloat = 1
    let identifier: String
    let text: String

    var body: some View {
        Color.clear
            .frame(width: Self.side, height: Self.side)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: text))
            .accessibilityIdentifier(identifier)
    }
}

/// The easing menu's items and the key shape each draws.
private enum GalleryEase: String, CaseIterable {
    case linear = "Linear"
    case easeIn = "Ease In"
    case easeOut = "Ease Out"
    case easeInOut = "Ease In Out"
    case hold = "Hold"

    var shape: TimelineKeyShape {
        switch self {
        case .linear: .linear
        case .easeIn, .easeOut, .easeInOut: .eased
        case .hold: .hold
        }
    }
}
