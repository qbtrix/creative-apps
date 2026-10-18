// SuiteToolPicking.swift: the floating tool palette's live rule (UC6),
// declared with its final signature so ToolbarGroup's `.floating` palette
// (EC-8) compiles against it. A stub for now: it returns FakeToolPicking's
// values, so a shortcut used twice is not yet a violation. EC-8b fills the
// body: the first enabled tool on a key, "Title (K)" or the reason as help,
// and empty reasons plus shared shortcuts as sorted violations.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteToolPicking: ToolPicking {
    private let stub = FakeToolPicking()

    public init() {}

    public func tool(forKey key: Character, in tools: [ToolFace]) -> String? { stub.tool(forKey: key, in: tools) }

    public func help(for tool: ToolFace) -> String { stub.help(for: tool) }

    public func violations(in tools: [ToolFace]) -> [String] { stub.violations(in: tools) }
}
