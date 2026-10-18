// SuiteToolPicking.swift: the floating tool palette's live rule (UC6), which
// ToolbarGroup's `.floating` palette (EC-8) picks by key and builds its help
// through. A key picks the first enabled tool on that shortcut, ignoring
// case, never a disabled one. Help is the reason while a tool can't act, else
// "Title (K)" with the shortcut uppercased, else the title alone. Violations
// are the ids of tools disabled with a blank reason and of every tool that
// shares a shortcut with another (disabled ones count: the key still
// collides), each id once, sorted.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteToolPicking: ToolPicking {
    public init() {}

    public func tool(forKey key: Character, in tools: [ToolFace]) -> String? {
        let wanted = key.lowercased()
        return tools.first { $0.unavailableHelp == nil && $0.shortcut?.lowercased() == wanted }?.id
    }

    public func help(for tool: ToolFace) -> String {
        if let reason = tool.unavailableHelp { return reason }
        guard let key = tool.shortcut else { return tool.title }
        return "\(tool.title) (\(key.uppercased()))"
    }

    public func violations(in tools: [ToolFace]) -> [String] {
        var onKey: [String: Int] = [:]
        for key in tools.compactMap({ $0.shortcut?.lowercased() }) { onKey[key, default: 0] += 1 }
        let broken = tools.filter { tool in
            let blankReason = tool.unavailableHelp.map { $0.allSatisfy(\.isWhitespace) } ?? false
            let sharedKey = tool.shortcut.map { (onKey[$0.lowercased()] ?? 0) > 1 } ?? false
            return blankReason || sharedKey
        }
        return Array(Set(broken.map(\.id))).sorted()
    }
}
