// GalleryChrome.swift: the gallery's editor-chrome pages. `editor` holds the
// chrome parts over GalleryEditorPage, its state and log: the
// TransportCapsule (48 frames at 24 fps, from frame 12), the Adjust | Layers
// capsule tabs, a floating ToolbarGroup of tools a, b and c (c disabled,
// saying why), switches for `frameCount` 0, Reduce Motion and the warning
// pill, and a ViewerStatusBar at 200% over 1920 × 1080 with an Onion toggle
// pill and a warning pill. The transport and the pills run on the live rules
// (SuiteTransport, SuiteStatusPills), or on their Fakes under
// -SuiteGalleryFakes. Each change writes one line to the `suite.gallery.log`
// element the journeys read: `play on`, `frame 13`, `loop on`, `toggle onion`,
// `tab layers`, `tool b`, `frames 0`, `reduce motion on`, `warning off`.
// The timecode's tooltip, which XCUITest can't read, is also the label of the
// hidden `suite.gallery.editor.timecode-help` readout (SJ5).
// `empty` shows EmptyStateView with its primary action (log `action new`)
// and the variant with no action. `save-status` draws EditorSaveStatus in
// its three states.
import SwiftUI

enum GalleryChrome {
    @MainActor static let pages: GalleryPages = [
        "editor": { AnyView(GalleryChromeEditor()) },
        "empty": { AnyView(GalleryChromeEmpty()) },
        "save-status": { AnyView(GallerySaveStatusPage()) },
    ]
}

/// The `editor` page's state: what each control shows, and the log line each change writes.
struct GalleryEditorPage: Equatable {
    static let tabs = [InspectorOption(id: "adjust", title: "Adjust"), InspectorOption(id: "layers", title: "Layers")]
    static let toolReason = "Tool C needs a layer to act on."

    private(set) var transport = TransportState(frame: 12, frameCount: 48, fps: 24)
    private(set) var noFrames = false
    private(set) var reduceMotion = false
    private(set) var onion = false
    private(set) var warning = true
    private(set) var tab = "adjust"
    private(set) var tool = "a"
    private(set) var lines: [String] = []

    /// What the capsule draws: nothing to play while the `frameCount` 0 switch is on.
    var shownTransport: TransportState {
        guard noFrames else { return transport }
        return TransportState(frame: 0, frameCount: 0, fps: transport.fps, loops: transport.loops)
    }

    mutating func play() {
        transport.isPlaying.toggle()
        note(transport.isPlaying ? "play on" : "play off")
    }

    /// Takes a stepped state; ignored while there is nothing to play.
    mutating func move(to next: TransportState) {
        guard !noFrames else { return }
        transport = next
        note("frame \(next.frame)")
    }

    mutating func setLoops(_ loops: Bool) {
        transport.loops = loops
        note(loops ? "loop on" : "loop off")
    }

    mutating func toggleOnion() {
        onion.toggle()
        note("toggle onion")
    }

    mutating func select(tab id: String) {
        tab = id
        note("tab \(id)")
    }

    mutating func select(tool id: String) {
        tool = id
        note("tool \(id)")
    }

    mutating func setNoFrames(_ on: Bool) {
        noFrames = on
        note("frames \(shownTransport.frameCount)")
    }

    mutating func setReduceMotion(_ on: Bool) {
        reduceMotion = on
        note(on ? "reduce motion on" : "reduce motion off")
    }

    mutating func setWarning(_ on: Bool) {
        warning = on
        note(on ? "warning on" : "warning off")
    }

    /// Appends one log line, keeping the last 40.
    private mutating func note(_ line: String) {
        lines = Array((lines + [line]).suffix(40))
    }
}

/// The `editor` page: transport, tabs, the floating palette, the switches, the pills and the log.
private struct GalleryChromeEditor: View {
    @Environment(\.galleryRequest) private var request
    @State private var page = GalleryEditorPage()

    /// The live transport rule, or the contract's Fake under -SuiteGalleryFakes.
    private var stepping: any TransportStepping {
        if request?.fakes == true { return FakeTransportStepping() }
        return SuiteTransport()
    }

    /// The live pill rule, or the contract's Fake (raw zoom text) under -SuiteGalleryFakes.
    private var composing: any StatusPillComposing {
        if request?.fakes == true { return FakeStatusPillComposing() }
        return SuiteStatusPills()
    }

    var body: some View {
        let transport = page.shownTransport
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            TransportCapsule(
                state: transport, stepping: stepping,
                onPlay: { page.play() },
                onStep: { page.move(to: stepping.stepped(transport, by: $0)) },
                onStart: { page.move(to: stepping.toStart(transport)) },
                onEnd: { page.move(to: stepping.toEnd(transport)) },
                onLoop: { page.setLoops($0) })
                .background(alignment: .topLeading) {
                    GalleryTimelineReadout(
                        identifier: "suite.gallery.editor.timecode-help", text: stepping.face(transport).timecodeHelp ?? "")
                }
            SegmentedTabs(
                "Panel", tabs: GalleryEditorPage.tabs, selection: page.tab, id: "suite.gallery.editor.tabs"
            ) { page.select(tab: $0) }
            ToolbarGroup([
                tool("a", systemImage: "cursorarrow"),
                tool("b", systemImage: "paintbrush.pointed"),
                tool("c", systemImage: "eraser", reason: GalleryEditorPage.toolReason),
            ])
            pageSwitch("Nothing to play (frameCount 0)", id: "no-frames", isOn: page.noFrames) { page.setNoFrames($0) }
            pageSwitch("Reduce Motion", id: "reduce-motion", isOn: page.reduceMotion) { page.setReduceMotion($0) }
            pageSwitch("Warning pill", id: "warning", isOn: page.warning) { page.setWarning($0) }
            Spacer(minLength: 0)
            ViewerStatusBar(zoom: 2, documentSize: PlaneExtent(width: 1920, height: 1080), composing: composing) {
                Text("Onion")
                    .statusPill(.toggle(isOn: page.onion), id: "suite.gallery.editor.onion", help: "Onion skin") {
                        page.toggleOnion()
                    }
                if page.warning {
                    Text("Dropping frames")
                        .accessibilityIdentifier("suite.gallery.editor.warning-pill")
                        .statusPill(.warning)
                }
            }
            GalleryLog(lines: page.lines)
        }
        .environment(\.suiteReduceMotion, page.reduceMotion)
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Tool `id` ("Tool A", key A), registered as `suite.gallery.editor.tool.<id>`; disabled while `reason` is set.
    private func tool(_ id: String, systemImage: String, reason: String? = nil) -> ToolbarAction {
        ToolbarAction(
            "Tool \(id.uppercased())", systemImage: systemImage, isSelected: page.tool == id,
            unavailableHelp: reason, shortcut: id.first, identifier: "suite.gallery.editor.tool.\(id)"
        ) { page.select(tool: id) }
    }

    /// A page switch, registered as `suite.gallery.editor.<id>`.
    private func pageSwitch(
        _ title: String, id: String, isOn: Bool, onChange: @escaping @MainActor (Bool) -> Void
    ) -> some View {
        Toggle(title, isOn: Binding(get: { isOn }, set: { onChange($0) }))
            .toggleStyle(.switch)
            .help(title)
            .suiteControl(id: "suite.gallery.editor.\(id)", enabled: true, reason: nil)
    }
}

/// The `empty` page: the empty state with its primary action, and the variant with none.
private struct GalleryChromeEmpty: View {
    @State private var lines: [String] = []

    var body: some View {
        VStack(spacing: SuiteSpacing.m) {
            EmptyStateView(
                "No Document", systemImage: "doc", message: "Create a document to start drawing.",
                action: ToolbarAction(
                    "New Document", systemImage: "doc.badge.plus", identifier: "suite.gallery.empty.new"
                ) { lines.append("action new") })
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suite.gallery.empty.action")
            EmptyStateView(
                "Nothing Selected", systemImage: "square.dashed", message: "Select a layer to see its settings.")
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suite.gallery.empty.plain")
            GalleryLog(lines: lines)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The `suite.gallery.log` element: the last line drawn, every line as its label.
private struct GalleryLog: View {
    let lines: [String]

    var body: some View {
        Text(lines.last ?? "Nothing yet")
            .lineLimit(1)
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .accessibilityIdentifier("suite.gallery.log")
            .accessibilityLabel(lines.joined(separator: "\n"))
            .accessibilityValue(lines.joined(separator: "\n"))
    }
}

private struct GallerySaveStatusPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            EditorSaveStatus(.saved, title: "Saved", help: "Every change is saved.", identifier: "suite.gallery.save.saved")
            EditorSaveStatus(.edited, title: "Edited", help: "Save to keep your changes.", identifier: "suite.gallery.save.edited")
            EditorSaveStatus(.notSaved, title: "Not saved", help: "The disk is full.", identifier: "suite.gallery.save.failed")
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
