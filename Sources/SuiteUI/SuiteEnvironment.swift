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
// every one of them (KeyframeButton, #1282). Plain keys rather than
// `@Entry`, as in Glass.swift.
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
    /// reason while unavailable; nil without an identifier.
    public func controlEntry(role: String? = nil) -> ControlEntry? {
        guard let identifier else { return nil }
        return ControlEntry(id: identifier, enabled: isEnabled, reason: isEnabled ? nil : help, role: role)
    }
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

private struct SuiteProbesModifier: ViewModifier {
    let requested: Bool
    @Environment(\.suiteProbesHosted) private var hosted
    @StateObject private var store = SuiteControlStore()
    @State private var probe = SuiteFrameProbe()

    func body(content: Content) -> some View {
        if requested && !hosted {
            content
                .environment(\.suiteProbesHosted, true)
                .environment(\.suiteControlStore, store)
                .background(alignment: .topLeading) {
                    SuitePerfElement(probe: probe, refreshInterval: SuiteFrameProbe.fallbackRefreshInterval)
                        .preference(key: SuiteProbeElementsKey.self, value: [SuitePerfElement.identifier])
                    SuiteControlsElement(store: store)
                        .preference(key: SuiteProbeElementsKey.self, value: [SuiteControlsElement.identifier])
                }
        } else {
            content
        }
    }
}
