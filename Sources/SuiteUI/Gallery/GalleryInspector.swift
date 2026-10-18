// GalleryInspector.swift: the gallery's inspector pages (blueprint suiteui
// 4.2, 4.3, 6.3). `inspector` draws every inspector row over the page's own
// @State: the title, a TRANSFORM section with Reset (the Rotation bar slider
// and its KeyframeButton, the X exact field, a disabled Skew row), STYLE (the
// Fill color row with its hex field, the Cap picker, a checkbox row, a
// disabled action) and MOTION (easing presets, blend chips, the Onion chip).
// `curves` draws the easing CurveEditor, the ToneCurveEditor and a
// StudioScrubRow. Each page writes one line per callback to
// `suite.gallery.log` (`rotation 40°`, `rotation 40° ends 1`, `color #FF3B30`,
// `reset transform`, `cap round`, `key add, Keyed at this frame`,
// `preset ease-out`, `chip onion on`, `handle1 x 0.42, y 0.10`,
// `points 4`); `ends n` counts every onEnd so far. `-SuiteGalleryWidth`
// pins the panel's width (SJ24), each page's Reduce Motion switch sets
// `suiteReduceMotion` on its components (SJ15, SJ20), and
// `-SuiteGalleryFakes` swaps each conformance the page uses for IC-1's Fake.
// The easing curve's samples come from the kernel's `EaseCurve`, so the
// drawn line is empty until EK-15 fills that stub; the handles still drag.
import enum SuiteKernel.EaseCurve
import SwiftUI

enum GalleryInspector {
    @MainActor static let pages: GalleryPages = [
        "inspector": { AnyView(GalleryInspectorPage()) },
        "curves": { AnyView(GalleryCurvesPage()) },
    ]
}

/// The `inspector` page: every inspector row over the page's own state.
private struct GalleryInspectorPage: View {
    private static let rotationSpec = ScrubSpec(range: -180...180, step: 1, decimals: 0, unit: "°")
    private static let xSpec = ScrubSpec(range: -4000...4000, step: 1, decimals: 0, unit: "px")
    private static let locked = "Locked while the gallery shows a disabled row."
    @Environment(\.galleryRequest) private var request
    @State private var rotation = 0.0
    @State private var x = 0.0
    @State private var fill = HexColor(0x18, 0x77, 0xF2)
    @State private var cap = "butt"
    @State private var snap = false
    @State private var key: KeyState = .idle
    @State private var preset: String?
    @State private var blend: String? = "normal"
    @State private var onion = false
    @State private var reduceMotion = false
    @State private var log = GalleryInspectorLog()

    private var fakes: Bool { request?.fakes == true }
    private var scrubbing: any ValueScrubbing { fakes ? FakeValueScrubbing() : SuiteValueScrubbing() }
    private var hex: any HexColorEditing { fakes ? FakeHexColorEditing() : HexColorText() }
    private var facing: any KeyframeFacing { fakes ? FakeKeyframeFacing() : SuiteKeyframeFacing() }
    private var navigation: any PresetNavigating { fakes ? FakePresetNavigating() : SuitePresetNavigating() }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(spacing: SuiteSpacing.xs) {
                GallerySwitch(title: "Reduce Motion", id: "suite.gallery.inspector.reduce-motion", isOn: reduceMotion) {
                    reduceMotion.toggle()
                }
                GallerySwitch(title: "Animated", id: "suite.gallery.inspector.animated", isOn: key == .animated) {
                    setKey(.animated, "state")
                }
                GallerySwitch(title: "Keyed here", id: "suite.gallery.inspector.keyed-here", isOn: key == .keyedHere) {
                    setKey(.keyedHere, "state")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: SuiteSpacing.m) {
                    InspectorHeader("Ball", details: ["Ellipse", "120 × 80 px"])
                    transform
                    style
                    motion
                }
                .padding(.vertical, SuiteSpacing.m)
            }
            .frame(width: GalleryInspectorLog.panelWidth(request))
            .environment(\.suiteReduceMotion, reduceMotion)
            GalleryInspectorLogView(log: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    private var transform: some View {
        InspectorSection("Transform", onReset: rotation != 0 || x != 0 ? { reset() } : nil) {
            HStack(spacing: SuiteSpacing.xs) {
                InspectorSliderRow(
                    "Rotation", value: rotation, in: Self.rotationSpec.range, step: Self.rotationSpec.step, unit: "°",
                    decimals: 0, keyed: key != .idle,
                    onChange: { new in
                        rotation = new
                        log.write("rotation \(scrubbing.text(new, spec: Self.rotationSpec))")
                    },
                    onEnd: { log.end("rotation \(scrubbing.text(rotation, spec: Self.rotationSpec))") })
                    .suiteControl(id: "suite.gallery.inspector.rotation", enabled: true, reason: nil)
                KeyframeButton(
                    "Rotation", id: "suite.gallery.inspector.keyframe-rotation", state: key, facing: facing,
                    registers: true, onToggle: toggleAnimation, onKey: toggleKey)
            }
            InspectorRow("X") {
                ScrubField(
                    "X", value: x, in: Self.xSpec.range, step: Self.xSpec.step, unit: "px", decimals: 0,
                    onChange: { new in
                        x = new
                        log.write("x \(scrubbing.text(new, spec: Self.xSpec))")
                    },
                    onEnd: { log.end("x \(scrubbing.text(x, spec: Self.xSpec))") })
                    .suiteControl(id: "suite.gallery.inspector.x", enabled: true, reason: nil)
            }
            InspectorSliderRow("Skew", value: 0, in: -45...45, step: 1, unit: "°", decimals: 0, onChange: { _ in })
                .disabled(true)
                .help(Self.locked)
                .suiteControl(id: "suite.gallery.inspector.skew", enabled: false, reason: Self.locked)
        }
        .galleryRegisters(
            [InspectorSection<EmptyView>.headerIdentifier("Transform")]
                + (rotation != 0 || x != 0 ? [InspectorSection<EmptyView>.headerIdentifier("Transform") + ".reset"] : []))
    }

    private var style: some View {
        InspectorSection("Style") {
            InspectorColorWellRow(
                "Fill", color: fill,
                onChange: { new in
                    fill = new
                    log.write("color \(hex.format(new.rgb))")
                },
                onEnd: { log.end("color \(hex.format(fill.rgb))") })
                .suiteControl(id: "suite.gallery.inspector.fill", enabled: true, reason: nil)
            InspectorPickerRow(
                "Cap", options: ["butt", "round", "square"].map { InspectorOption(id: $0, title: $0.capitalized) },
                selection: cap
            ) { new in
                cap = new
                log.write("cap \(new)")
            }
            .suiteControl(id: "suite.gallery.inspector.cap", enabled: true, reason: nil)
            InspectorRow("") {
                Toggle("Snap to Pixels", isOn: Binding(get: { snap }, set: { on in
                    snap = on
                    log.write("snap \(on ? "on" : "off")")
                }))
                .toggleStyle(.checkbox)
                .suiteControl(id: "suite.gallery.inspector.snap", enabled: true, reason: nil)
            }
            InspectorAction(ToolbarAction(
                "Convert to Path", systemImage: "scribble", unavailableHelp: "The gallery has no shape to convert.",
                identifier: "suite.gallery.inspector.action-convert"))
        }
        .galleryRegisters([InspectorSection<EmptyView>.headerIdentifier("Style")])
    }

    private var motion: some View {
        let presets = ["linear", "ease-in", "ease-out", "ease-in-out"].map { id in
            InspectorOption(id: id, title: Self.title(id), identifier: "suite.gallery.inspector.preset-\(id)")
        }
        let blends = ["normal", "multiply", "screen"].map { id in
            InspectorOption(id: id, title: Self.title(id), identifier: "suite.gallery.inspector.chip-\(id)")
        }
        return InspectorSection("Motion") {
            PresetGrid(options: presets, selected: preset, navigation: navigation) { id in
                preset = id
                log.write("preset \(id)")
            }
            .galleryRegisters(presets.compactMap(\.identifier))
            ChoiceChips(options: blends, selected: blend, navigation: navigation) { id in
                blend = id
                log.write("blend \(id)")
            }
            .galleryRegisters(blends.compactMap(\.identifier))
            GallerySwitch(title: "Onion", id: "suite.gallery.inspector.chip-onion", isOn: onion) {
                onion.toggle()
                log.write("chip onion \(onion ? "on" : "off")")
            }
        }
        .galleryRegisters([InspectorSection<EmptyView>.headerIdentifier("Motion")])
    }

    /// "ease-out" as "Ease Out".
    private static func title(_ id: String) -> String {
        id.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    private func reset() {
        rotation = 0
        x = 0
        log.write("reset transform")
    }

    /// The stopwatch: turns animation on with a key here, or off.
    private func toggleAnimation() {
        key == .idle ? setKey(.keyedHere, "key add") : setKey(.idle, "key off")
    }

    /// The diamond: adds the key at the playhead, or removes the one there.
    private func toggleKey() {
        switch key {
        case .idle: break
        case .animated: setKey(.keyedHere, "key add")
        case .keyedHere: setKey(.animated, "key remove")
        }
    }

    private func setKey(_ state: KeyState, _ what: String) {
        key = state
        log.write("\(what), \(facing.face(for: state.presence).spoken)")
    }
}

/// The `curves` page: the easing curve, the tone curve and a Studio row.
private struct GalleryCurvesPage: View {
    @Environment(\.galleryRequest) private var request
    @State private var handles = (CGPoint(x: 0.42, y: 0), CGPoint(x: 0.58, y: 1))
    @State private var points = [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 1)]
    @State private var duration = 0.5
    @State private var reduceMotion = false
    @State private var log = GalleryInspectorLog()

    private var nudging: any EasingHandleNudging {
        request?.fakes == true ? FakeEasingHandleNudging() : SuiteEasingHandleNudging()
    }

    /// Bins for the tone curve's histogram: any heights, drawn normalised.
    private static let histogram = (0..<32).map { Double(($0 * 7) % 13 + 2) }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            GallerySwitch(title: "Reduce Motion", id: "suite.gallery.curves.reduce-motion", isOn: reduceMotion) {
                reduceMotion.toggle()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: SuiteSpacing.m) {
                    CurveEditor(
                        samples: Self.samples(handles), handles: handles, id: "suite.gallery.curves.easing",
                        nudging: nudging,
                        onMove: { index, point in
                            if index == .first { handles.0 = point } else { handles.1 = point }
                            log.write("handle\(index.rawValue) \(nudging.describe(PlanePoint(x: point.x, y: point.y)))")
                        },
                        onEnd: { log.end("easing") })
                    StudioScrubRow(
                        label: "Duration", value: duration, range: 0...10, step: 0.1,
                        onChange: { new in
                            duration = new
                            log.write("duration \(NumericInput.text(new, decimals: 2, unit: "s"))")
                        },
                        onEnd: { log.end("duration") })
                        .suiteControl(id: "suite.gallery.curves.duration", enabled: true, reason: nil)
                    ToneCurveEditor(
                        points: points, samples: points, histogram: Self.histogram, id: "suite.gallery.curves.tone",
                        onChange: { new in
                            points = new
                            log.write("points \(new.count)")
                        },
                        onEnd: { log.end("tone") })
                }
                .padding(SuiteSpacing.m)
            }
            .frame(width: GalleryInspectorLog.panelWidth(request))
            .environment(\.suiteReduceMotion, reduceMotion)
            GalleryInspectorLogView(log: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    /// 64 points along the kernel's curve for the two handles.
    private static func samples(_ handles: (CGPoint, CGPoint)) -> [CGPoint] {
        EaseCurve.samples(
            of: .cubicBezier(
                x1: Double(handles.0.x), y1: Double(handles.0.y), x2: Double(handles.1.x), y2: Double(handles.1.y)),
            count: 64
        ).map { CGPoint(x: $0.x, y: $0.y) }
    }
}

/// A page's log: the last 40 lines and how many onEnd calls came so far.
private struct GalleryInspectorLog {
    private(set) var lines: [String] = []
    private(set) var ends = 0

    mutating func write(_ line: String) {
        lines.append(line)
        if lines.count > 40 { lines.removeFirst(lines.count - 40) }
    }

    /// One onEnd: counts it and writes `<what> ends <n>`.
    mutating func end(_ what: String) {
        ends += 1
        write("\(what) ends \(ends)")
    }

    /// The panel's width: `-SuiteGalleryWidth`, or the inspector's ideal.
    static func panelWidth(_ request: GalleryRequest?) -> CGFloat {
        guard let width = request?.width, width.isFinite, width > 0 else { return SuiteSize.inspectorWidth.ideal }
        return CGFloat(width)
    }
}

/// The log row at the page's foot: the last line shown, the whole log as the
/// label and value of `suite.gallery.log`.
private struct GalleryInspectorLogView: View {
    let log: GalleryInspectorLog

    var body: some View {
        let text = log.lines.joined(separator: "\n")
        Text(log.lines.last ?? "Nothing yet")
            .font(SuiteFont.timecode)
            .foregroundStyle(SuiteColor.secondaryText)
            .lineLimit(1)
            .accessibilityLabel(text)
            .accessibilityValue(text)
            .accessibilityIdentifier("suite.gallery.log")
    }
}

/// One page switch: a ChipRow of one chip, so its identifier lands on that chip alone.
private struct GallerySwitch: View {
    let title: String
    let id: String
    let isOn: Bool
    let toggle: @MainActor () -> Void

    var body: some View {
        ChipRow([ChipItem(id: id, title: title, isOn: isOn)]) { _ in toggle() }
            .help(title)
            .suiteControl(id: id, enabled: true, reason: nil)
    }
}

private extension View {
    /// Lists `ids` in `suite.controls`, enabled, keeping the identifiers the
    /// components set on their own buttons (presets, chips, section headers).
    func galleryRegisters(_ ids: [String]) -> some View {
        background {
            ForEach(ids, id: \.self) { id in
                Color.clear.suiteControl(id: id, enabled: true, reason: nil, identifies: false)
            }
        }
    }
}
