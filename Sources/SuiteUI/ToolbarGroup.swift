// ToolbarGroup.swift: ToolbarAction (one command: title, SF Symbol, selected
// state, why it is unavailable, handler) and ToolbarGroup, a floating tool
// palette of icon buttons over a canvas. The whole group sits in one glass
// capsule (one glass shape, no glass on glass); the selected tool is a flat
// accent tint inside it. Window toolbar items use the same ToolbarAction
// through SuiteWindow. An action can only be disabled by saying why: its
// `unavailableHelp` is the tooltip, so no shown control is silently dead.
// Apps build their canvas palette from their Model's tool enum through
// PaletteTool, which carries that reason for every tool.
import SwiftUI

public struct ToolbarAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let isSelected: Bool
    /// Why the action can't run right now; nil when it can. Non-nil shows the
    /// item disabled with this text as its tooltip.
    public let unavailableHelp: String?
    public let perform: @MainActor () -> Void

    /// `title` is also the id, the tooltip and the accessibility label, so it
    /// must be unique within a group.
    public init(
        _ title: String, systemImage: String, isSelected: Bool = false, unavailableHelp: String? = nil,
        perform: @escaping @MainActor () -> Void = {}
    ) {
        self.id = title
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.unavailableHelp = unavailableHelp
        self.perform = perform
    }

    public var isEnabled: Bool { unavailableHelp == nil }

    /// The tooltip: why the action is unavailable, or else its title.
    public var help: String { unavailableHelp ?? title }
}

/// A tool on a canvas palette. Each app conforms its Model's tool enum, so
/// every palette shows a tool that can't act yet as disabled, saying why.
public protocol PaletteTool: Hashable {
    var title: String { get }
    var systemImage: String { get }
    /// Why the tool can't be used yet; nil once it works.
    var unavailableHelp: String? { get }
}

public struct ToolbarGroup: View {
    private let actions: [ToolbarAction]
    private let axis: Axis

    public init(_ actions: [ToolbarAction], axis: Axis = .horizontal) {
        self.actions = actions
        self.axis = axis
    }

    /// A vertical tool palette: one button per tool, `selected` highlighted;
    /// a click on an enabled tool calls `onSelect`.
    public init<Tool: PaletteTool>(tools: [Tool], selected: Tool, onSelect: @escaping @MainActor (Tool) -> Void) {
        self.init(tools.map { tool in
            ToolbarAction(
                tool.title, systemImage: tool.systemImage, isSelected: tool == selected,
                unavailableHelp: tool.unavailableHelp) { onSelect(tool) }
        }, axis: .vertical)
    }

    public var body: some View {
        let stack = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        stack {
            ForEach(actions) { action in
                // A disabled tool never shows as the selected one.
                let isSelected = action.isSelected && action.isEnabled
                Button(action: action.perform) {
                    Image(systemName: action.systemImage)
                        .symbolVariant(isSelected ? .fill : .none)
                        .foregroundStyle(Self.symbolStyle(action))
                        .frame(width: SuiteSize.toolButton, height: SuiteSize.toolButton)
                        .background(isSelected ? SuiteColor.accent.opacity(0.15) : .clear, in: Circle())
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!action.isEnabled)
                // After .disabled, so the tooltip still shows on a disabled tool.
                .help(action.help)
                .accessibilityLabel(action.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(SuiteSpacing.xs)
        .suiteGlass(in: Capsule())
    }

    /// Accent when selected, primary when enabled, tertiary (dimmed) when not;
    /// set here because a plain button style does not dim reliably everywhere.
    private static func symbolStyle(_ action: ToolbarAction) -> AnyShapeStyle {
        guard action.isEnabled else { return AnyShapeStyle(HierarchicalShapeStyle.tertiary) }
        return action.isSelected ? AnyShapeStyle(SuiteColor.accent) : AnyShapeStyle(Color.primary)
    }
}
