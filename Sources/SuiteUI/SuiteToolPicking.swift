// SuiteToolPicking.swift: the floating tool palette's live rule (UC6). A stub
// with its final signature until EC-8b of the editor-chrome packet fills it:
// today every call returns FakeToolPicking's value. EC-8b adds the
// duplicate-shortcut violation (case-insensitive, sorted ids). Foundation
// only.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteToolPicking: ToolPicking {
    public init() {}
    public func tool(forKey key: Character, in tools: [ToolFace]) -> String? {
        FakeToolPicking().tool(forKey: key, in: tools)
    }
    public func help(for tool: ToolFace) -> String { FakeToolPicking().help(for: tool) }
    public func violations(in tools: [ToolFace]) -> [String] { FakeToolPicking().violations(in: tools) }
}
