// ControlInventory.swift: SuiteControlInventory, the live ControlInventorying
// (UC18, #775) behind `suite.controls`. Each registration remembers the view
// that made it, so one view re-registering is an update, while two views on
// screen with one id is a violation (the duplicate FakeControlInventory never
// reports); a view unregisters when it disappears, so a pushed page doesn't
// count twice. A call through the protocol's `register(_:)` counts as a new
// view. SuiteControlStore holds a window's inventory for `.suiteControl` and
// SuiteControlsElement publishes its JSON as the label of a hidden element,
// placed by `.suiteProbes()` (SuiteEnvironment.swift). The rules are
// Foundation only (ControlInventoryTests). `.suiteControl(entry:identifies:)`
// lists a whole entry, so the toggle-style controls (InspectorAction,
// SegmentedTabs, KeyframeButton) report `selected` (ControlStateTests).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteControlInventory: ControlInventorying {
    private struct Registration: Hashable, Sendable {
        var owner: UUID
        var entry: ControlEntry
    }

    private var registrations: [String: [Registration]] = [:]

    public init() {}

    /// An inventory of `entries`, each its own view's; `document()` keeps the last placed per id.
    public init(entries: [ControlEntry]) {
        for entry in entries { register(entry) }
    }

    /// Registers `entry` as a new view's control.
    public mutating func register(_ entry: ControlEntry) { register(entry, owner: UUID()) }

    /// Registers or updates `owner`'s control `entry`; a second owner of one id is a duplicate.
    public mutating func register(_ entry: ControlEntry, owner: UUID) {
        var list = registrations[entry.id, default: []]
        if let index = list.firstIndex(where: { $0.owner == owner }) {
            list[index].entry = entry
        } else {
            list.append(Registration(owner: owner, entry: entry))
        }
        registrations[entry.id] = list
    }

    /// Drops every registration of `id`.
    public mutating func unregister(_ id: String) { registrations[id] = nil }

    /// Drops `owner`'s registration of `id`, leaving any other view's.
    public mutating func unregister(_ id: String, owner: UUID) {
        let list = (registrations[id] ?? []).filter { $0.owner != owner }
        registrations[id] = list.isEmpty ? nil : list
    }

    /// Moves `owner`'s control from `old` to `new`: drops `old` when `new` is nil or has another id,
    /// then registers `new`. A view that places its entry, changes it and leaves calls this each time.
    public mutating func place(_ new: ControlEntry?, replacing old: ControlEntry?, owner: UUID) {
        if let old, old.id != new?.id { unregister(old.id, owner: owner) }
        if let new { register(new, owner: owner) }
    }

    public func violations() -> [String] {
        registrations.compactMap { id, list in
            let dead = list.contains { !$0.entry.enabled && ($0.entry.reason ?? "").isEmpty }
            return list.count > 1 || dead ? id : nil
        }.sorted()
    }

    /// One entry per id, the latest registered, sorted by id.
    public func document() -> ControlDocument {
        ControlDocument(controls: registrations.values.compactMap(\.last?.entry).sorted { $0.id < $1.id })
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(document())
    }

    /// The `suite.controls` label text: the encoded document, or `{}` when it can't encode.
    public func json() -> String {
        guard let data = try? encoded() else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

#if canImport(SwiftUI)
import Combine
import SwiftUI

/// A window's inventory, shared through the environment by `.suiteProbes()`.
@MainActor public final class SuiteControlStore: ObservableObject {
    @Published public private(set) var inventory = SuiteControlInventory()

    public init() {}

    func register(_ entry: ControlEntry, owner: UUID) { inventory.register(entry, owner: owner) }

    func unregister(_ id: String, owner: UUID) { inventory.unregister(id, owner: owner) }

    func place(_ new: ControlEntry?, replacing old: ControlEntry?, owner: UUID) {
        inventory.place(new, replacing: old, owner: owner)
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

/// The hidden `suite.controls` element: no hits, its label the inventory's JSON.
public struct SuiteControlsElement: View {
    public static let identifier = "suite.controls"
    @ObservedObject var store: SuiteControlStore

    public var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: store.inventory.json()))
            .accessibilityIdentifier(Self.identifier)
    }
}
#endif
