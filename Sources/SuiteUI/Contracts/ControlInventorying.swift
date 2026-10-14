// ControlInventorying.swift: UC18, the suite.controls contract (no dead
// controls) and FakeControlInventory, which never reports a duplicate id on
// purpose. Foundation only; verbatim from blueprint section 5.3. The live
// inventory is SH-5.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct ControlEntry: Hashable, Sendable, Codable {
    public var id: String
    public var enabled: Bool
    public var reason: String?
    public var role: String?              // "primary" for the one prominent action; nil otherwise
    public init(id: String, enabled: Bool, reason: String? = nil, role: String? = nil) {
        self.id = id; self.enabled = enabled; self.reason = reason; self.role = role
    }
}

/// The `suite.controls` document, published like `suite.perf` (label of a hidden element `suite.controls`).
/// `role` lets a journey find the one primary action without reading a style.
public struct ControlDocument: Hashable, Sendable, Codable {
    public var controls: [ControlEntry]   // sorted by id
    public init(controls: [ControlEntry]) { self.controls = controls }
}

public protocol ControlInventorying: Sendable {
    mutating func register(_ entry: ControlEntry)
    mutating func unregister(_ id: String)
    /// Ids that break "no dead controls": disabled with no reason, or an id registered twice.
    func violations() -> [String]
    func document() -> ControlDocument
    /// The `suite.controls` JSON: `document()` encoded.
    func encoded() throws -> Data
}

/// Keeps the last entry per id; never reports a duplicate.
public struct FakeControlInventory: ControlInventorying {
    public private(set) var entries: [String: ControlEntry] = [:]
    public init() {}
    public mutating func register(_ entry: ControlEntry) { entries[entry.id] = entry }
    public mutating func unregister(_ id: String) { entries[id] = nil }
    public func violations() -> [String] {
        entries.values.filter { !$0.enabled && ($0.reason ?? "").isEmpty }.map(\.id).sorted()
    }
    public func document() -> ControlDocument { ControlDocument(controls: entries.values.sorted { $0.id < $1.id }) }
    public func encoded() throws -> Data { try JSONEncoder().encode(document()) }
}
