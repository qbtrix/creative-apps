// ToolPicking.swift: UC6, the floating tool palette's key pick and tooltip,
// and FakeToolPicking, which never flags a shortcut used twice on purpose
// (the live rule does). Foundation only; verbatim from
// docs/blueprints/suiteui/contracts/Contracts.swift. The live rule is
// SuiteToolPicking (EC-8b of the editor-chrome packet).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct ToolFace: Hashable, Sendable {
    public var id: String
    public var title: String
    public var shortcut: Character?
    public var unavailableHelp: String?
    public init(id: String, title: String, shortcut: Character? = nil, unavailableHelp: String? = nil) {
        self.id = id; self.title = title; self.shortcut = shortcut; self.unavailableHelp = unavailableHelp
    }
}

public protocol ToolPicking: Sendable {
    /// The enabled tool whose one-key shortcut is `key` (case-insensitive), if any.
    func tool(forKey key: Character, in tools: [ToolFace]) -> String?
    /// The tooltip: "Brush (B)" while enabled, the reason while not.
    func help(for tool: ToolFace) -> String
    /// Ids that break the palette's rules: disabled with an empty reason, or a shortcut used twice.
    func violations(in tools: [ToolFace]) -> [String]
}

/// Flags an empty reason only, never a shortcut used twice.
public struct FakeToolPicking: ToolPicking {
    public init() {}
    public func tool(forKey key: Character, in tools: [ToolFace]) -> String? {
        tools.first { $0.unavailableHelp == nil && $0.shortcut.map { $0.lowercased() == key.lowercased() } == true }?.id
    }
    public func help(for tool: ToolFace) -> String {
        if let reason = tool.unavailableHelp { return reason }
        return tool.shortcut.map { "\(tool.title) (\($0.uppercased()))" } ?? tool.title
    }
    public func violations(in tools: [ToolFace]) -> [String] {
        tools.filter { $0.unavailableHelp?.isEmpty == true }.map(\.id)
    }
}
