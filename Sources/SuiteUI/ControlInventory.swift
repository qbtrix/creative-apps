// ControlInventory.swift: SuiteControlInventory, the live ControlInventorying
// (UC18, #775) behind `suite.controls`. Each registration remembers the view
// that made it, so one view re-registering is an update, while two views on
// screen with one id is a violation (the duplicate FakeControlInventory never
// reports); a view unregisters when it disappears, so a pushed page doesn't
// count twice. A call through the protocol's `register(_:)` counts as a new
// view. SuiteControlStore holds a window's inventory for `.suiteControl` and
// SuiteControlsElement publishes its JSON as the label of a hidden element,
// placed by `.suiteProbes()` (SuiteEnvironment.swift). The rules are
// Foundation only (ControlInventoryTests).
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
