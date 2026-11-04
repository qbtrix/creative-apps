// SuiteEnvironment.swift: what the harness puts in a window's environment.
// `suiteReduceMotion` is the system's Reduce Motion unless a view or a test
// sets it. `.suiteProbes()` publishes a window's `suite.perf` and
// `suite.controls` hidden elements under `-SuitePerfProbe`, only at the
// outermost call: it marks the environment, and an inner call that finds the
// mark adds nothing, so a gallery page that draws an EditorShell still has
// one of each. Each element also reports its identifier through
// SuiteProbeElementsKey, so a test counts what was placed without an
// assistive client (SwiftUI builds a hosting view's accessibility tree only
// when one asks). `.suiteControl(id:enabled:reason:role:identifies:)` sets the
// control's accessibility identifier and keeps it registered in that window's
// SuiteControlInventory while it is on screen; a nil id registers nothing.
// With `identifies` false it only registers, for a view whose parts carry
// their own identifiers: an identifier on a view of several elements lands on
// every one of them (KeyframeButton, #1282). `.suiteControl(entry:identifies:)`
// lists a whole entry, so the toggle-style controls (InspectorAction,
// SegmentedTabs, KeyframeButton) report `selected` (ControlStateTests).
// The publishing call also sets
// `gridProbe`, `scrubProbe`, `chipProbe`, `curveProbe` and `timelineFadeMark`,
// so grids, layer lists, scrub fields, chips, curve editors and the timeline
// record their frames, samples and marks into the window's `suite.perf` (SP1,
// SP3, SP4, SP6, SP7, SP8, SJ20), and
// `suiteProbeRecorder`, the window's SuiteProbeRecorder itself, so an app
// view records its own samples, drawn frames and marks into that one probe
// (#3401); outside a publishing call it is nil. Only the hidden element
// watches the recorder, so recording never runs the window's body or the
// recording view's. Plain keys rather than `@Entry`, as in Glass.swift.
import SwiftUI

extension EnvironmentValues {
    /// Whether to avoid motion: the system's Reduce Motion until set.
    public var suiteReduceMotion: Bool {
        get { self[SuiteReduceMotionKey.self] ?? accessibilityReduceMotion }
        set { self[SuiteReduceMotionKey.self] = newValue }
    }

    /// The inventory `.suiteControl` registers in; nil outside `.suiteProbes()`.
    var suiteControlStore: SuiteControlStore? {
        get { self[SuiteControlStoreKey.self] }
        set { self[SuiteControlStoreKey.self] = newValue }
    }

    /// The window's probe recorder; nil without `-SuitePerfProbe`, so every call through it is skipped.
    public var suiteProbeRecorder: SuiteProbeRecorder? {
        get { self[SuiteProbeRecorderKey.self] }
        set { self[SuiteProbeRecorderKey.self] = newValue }
    }

    /// True inside a `.suiteProbes()` that publishes.
    var suiteProbesHosted: Bool {
        get { self[SuiteProbesHostedKey.self] }
        set { self[SuiteProbesHostedKey.self] = newValue }
    }
}

private struct SuiteReduceMotionKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

private struct SuiteControlStoreKey: EnvironmentKey {
    static let defaultValue: SuiteControlStore? = nil
}

private struct SuiteProbeRecorderKey: EnvironmentKey {
    static let defaultValue: SuiteProbeRecorder? = nil
}

private struct SuiteProbesHostedKey: EnvironmentKey {
    static let defaultValue = false
}

/// The identifiers of the hidden elements `.suiteProbes()` placed, in tree order.
struct SuiteProbeElementsKey: PreferenceKey {
    static let defaultValue: [String] = []

    static func reduce(value: inout [String], nextValue: () -> [String]) { value += nextValue() }
}

extension View {
    /// Identifies this control and lists it in the window's `suite.controls`
    /// while it is on screen. A disabled control must say why in `reason`. A
    /// nil `id` lists nothing; with `identifies` false the view is listed but
    /// keeps the identifiers its parts set themselves.
    public func suiteControl(
        id: String?, enabled: Bool, reason: String?, role: String? = nil, identifies: Bool = true
    ) -> some View {
        let entry = id.map { ControlEntry(id: $0, enabled: enabled, reason: reason, role: role) }
        return modifier(SuiteControlModifier(entry: entry, identifies: identifies))
    }

    /// Publishes `suite.perf` and `suite.controls` when `arguments` carry
    /// `-SuitePerfProbe`, unless an enclosing `.suiteProbes()` already does.
    public func suiteProbes(arguments: [String] = ProcessInfo.processInfo.arguments) -> some View {
        modifier(SuiteProbesModifier(requested: SuiteFrameProbe.isRequested(by: arguments)))
    }

    /// Registers `action` when it has an identifier; otherwise changes nothing.
    func suiteControl(_ action: ToolbarAction, role: String? = nil) -> some View {
        modifier(SuiteControlModifier(entry: action.controlEntry(role: role)))
    }
}

extension ToolbarAction {
    /// The action's `suite.controls` entry: disabled with its tooltip as the
    /// reason while unavailable, a toggle's state as `selected`; nil without an identifier.
    public func controlEntry(role: String? = nil) -> ControlEntry? {
        guard let identifier else { return nil }
        return ControlEntry(id: identifier, enabled: isEnabled, reason: isEnabled ? nil : help, role: role)
            .selecting(toggleState)
    }

    /// A toggle's `selected`: on only while it is on and able to act (a disabled
    /// toggle draws off); nil for a plain action.
    var toggleState: Bool? { isToggle ? isSelected && isEnabled : nil }
}

private struct SuiteControlModifier: ViewModifier {
    let entry: ControlEntry?
    var identifies = true
    @Environment(\.suiteControlStore) private var store
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        if let entry, identifies {
            content
                .accessibilityIdentifier(entry.id)
                .onAppear { store?.register(entry, owner: owner) }
                .onChange(of: entry) { old, new in
                    if old.id != new.id { store?.unregister(old.id, owner: owner) }
                    store?.register(new, owner: owner)
                }
                .onDisappear { store?.unregister(entry.id, owner: owner) }
        } else if identifies {
            content
        } else {
            // Registers only. The entry may come and go without the content
            // changing identity, so every hook takes it as optional.
            content
                .onAppear { entry.map { store?.register($0, owner: owner) } }
                .onChange(of: entry) { old, new in
                    if let old, old.id != new?.id { store?.unregister(old.id, owner: owner) }
                    new.map { store?.register($0, owner: owner) }
                }
                .onDisappear { entry.map { store?.unregister($0.id, owner: owner) } }
        }
    }
}

extension View {
    /// Lists `entry` in the window's `suite.controls` while on screen, its
    /// `selected` state included, so a toggle-style SuiteUI control reports
    /// whether it is on; nil lists nothing. With `identifies` the entry's id
    /// is also the view's accessibility identifier.
    func suiteControl(entry: ControlEntry?, identifies: Bool) -> some View {
        modifier(SuiteControlEntryModifier(entry: entry, identifies: identifies))
    }
}

/// Places one entry for the view's lifetime; each change replaces the last one placed.
private struct SuiteControlEntryModifier: ViewModifier {
    let entry: ControlEntry?
    let identifies: Bool
    @Environment(\.suiteControlStore) private var store
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        Group {
            if identifies, let id = entry?.id { content.accessibilityIdentifier(id) } else { content }
        }
        .onAppear { store?.place(entry, replacing: nil, owner: owner) }
        .onChange(of: entry) { old, new in store?.place(new, replacing: old, owner: owner) }
        .onDisappear { store?.place(nil, replacing: entry, owner: owner) }
    }
}

private struct SuiteProbesModifier: ViewModifier {
    let requested: Bool
    @Environment(\.suiteProbesHosted) private var hosted
    @StateObject private var store = SuiteControlStore()
    @StateObject private var recorder = SuiteProbeRecorder()

    func body(content: Content) -> some View {
        if requested && !hosted {
            content
                .environment(\.suiteProbesHosted, true)
                .environment(\.suiteControlStore, store)
                .environment(\.gridProbe, recorder.gridProbe)
                .environment(\.scrubProbe, recorder.scrubProbe)
                .environment(\.chipProbe, recorder.chipProbe)
                .environment(\.curveProbe, recorder.curveProbe)
                .environment(\.timelineFadeMark, recorder.timelineProbe)
                .environment(\.suiteProbeRecorder, recorder)
                .background(alignment: .topLeading) {
                    SuitePerfHost(recorder: recorder)
                        .preference(key: SuiteProbeElementsKey.self, value: [SuitePerfElement.identifier])
                    SuiteControlsElement(store: store)
                        .preference(key: SuiteProbeElementsKey.self, value: [SuiteControlsElement.identifier])
                }
        } else {
            content
        }
    }
}

/// The window's frame probe behind `.suiteProbes()`, read by app views as
/// `suiteProbeRecorder`. Read it with `@Environment`, never `@ObservedObject`:
/// observing it runs the reader's body on every sample. Each control probe is
/// built once, so its environment value stays the same closure across passes.
@MainActor public final class SuiteProbeRecorder: ObservableObject {
    @Published private(set) var probe = SuiteFrameProbe()
    private(set) var gridProbe = GridProbe { _, _ in }
    private(set) var scrubProbe = ScrubProbe { _ in }
    private(set) var chipProbe = ChipProbe(record: { _ in }, sample: { _ in })
    private(set) var curveProbe = CurveProbe(record: { _ in }, mark: { _ in })
    private(set) var timelineProbe = TimelineFadeMark(record: { _ in })

    init() {
        gridProbe = GridProbe { [weak self] series, time in self?.probe.drew(series, at: time) }
        scrubProbe = ScrubProbe { [weak self] sample in self?.probe.record(sample) }
        chipProbe = ChipProbe(
            record: { [weak self] mark in self?.mark(mark) },
            sample: { [weak self] sample in self?.probe.record(sample) })
        curveProbe = CurveProbe(
            record: { [weak self] sample in self?.probe.record(sample) },
            mark: { [weak self] mark in self?.mark(mark) })
        timelineProbe = TimelineFadeMark(
            record: { [weak self] mark in self?.mark(mark) },
            sample: { [weak self] sample in self?.probe.record(sample) })
    }

    /// An input sample: the event's timestamp and the target timestamp of the refresh that showed it.
    public func record(_ sample: ProbeSample) { probe.record(sample) }

    /// A frame of `series` drawn at the target timestamp `time` (scrolls, playback).
    public func drew(_ series: String, at time: Double) { probe.drew(series, at: time) }

    /// An in-app moment on `series`, stamped now on the clock the control probes use.
    public func mark(_ name: String, series: String) {
        probe.mark(name, series: series, at: ProcessInfo.processInfo.systemUptime)
    }

    private func mark(_ mark: ProbeMark) {
        probe.mark(mark.name, series: mark.series, at: mark.time)
    }
}

/// `suite.perf` from the recorder: the only view that runs when a frame lands.
private struct SuitePerfHost: View {
    @ObservedObject var recorder: SuiteProbeRecorder

    var body: some View {
        SuitePerfElement(probe: recorder.probe, refreshInterval: SuiteFrameProbe.fallbackRefreshInterval)
    }
}
