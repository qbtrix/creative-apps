// ToolbarGroup.swift: ToolbarAction (one command: title, SF Symbol, selected
// state, why it is unavailable, its one-key shortcut, handler) and
// ToolbarGroup, a tool palette of icon buttons. Two styles: `.floating` sits
// over a canvas in one glass capsule (one glass shape, no glass on glass);
// `.rail` is the flat vertical tool rail docked at an EditorShell's leading
// edge. Either way the selected tool is a flat accent tint. Window toolbar
// items use the same ToolbarAction through SuiteWindow and EditorBarItem. An
// action can only be disabled by saying why: its `unavailableHelp` is the
// tooltip, so no shown control is silently dead. Apps build their palette
// from their Model's tool enum through PaletteTool, which carries that reason
// and the shortcut for every tool. The palette is one accessibility
// container, `suite.tools`, so the UI journeys in UITests/ can click every
// tool in it without listing them. An action with an `identifier` carries it
// as its accessibility identifier and lists itself in `suite.controls`.
import SwiftUI

public struct ToolbarAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let isSelected: Bool
    /// Why the action can't run right now; nil when it can. Non-nil shows the
    /// item disabled with this text as its tooltip.
    public let unavailableHelp: String?
    /// The key that picks it while the canvas has focus, shown in the tooltip.
    public let shortcut: Character?
    /// The control's accessibility identifier and `suite.controls` id; nil
    /// leaves it unidentified and unlisted.
    public var identifier: String?
    public let perform: @MainActor () -> Void

    /// `title` is also the id, the tooltip and the accessibility label, so it
    /// must be unique within a group.
    public init(
        _ title: String, systemImage: String, isSelected: Bool = false, unavailableHelp: String? = nil,
        shortcut: Character? = nil, identifier: String? = nil, perform: @escaping @MainActor () -> Void = {}
    ) {
        self.id = title
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.unavailableHelp = unavailableHelp
        self.shortcut = shortcut
        self.identifier = identifier
        self.perform = perform
    }

    public var isEnabled: Bool { unavailableHelp == nil }

    /// The tooltip: why the action is unavailable, or else its title with its
    /// shortcut ("Brush (B)").
    public var help: String {
        if let unavailableHelp { return unavailableHelp }
        guard let shortcut else { return title }
        return "\(title) (\(shortcut.uppercased()))"
    }
}

/// A tool on a canvas palette. Each app conforms its Model's tool enum, so
/// every palette shows a tool that can't act yet as disabled, saying why.
public protocol PaletteTool: Hashable {
    var title: String { get }
    var systemImage: String { get }
    /// Why the tool can't be used yet; nil once it works.
    var unavailableHelp: String? { get }
    /// The key that picks the tool while the canvas has focus; nil for none.
    var shortcut: Character? { get }
}

extension PaletteTool {
    public var shortcut: Character? { nil }
}

public struct ToolbarGroup: View {
    /// Floating over a canvas in a glass capsule, or docked flat as a rail.
    public enum Style: Sendable { case floating, rail }

    private let actions: [ToolbarAction]
    private let axis: Axis
    private let style: Style

    public init(_ actions: [ToolbarAction], axis: Axis = .horizontal, style: Style = .floating) {
        self.actions = actions
        self.axis = style == .rail ? .vertical : axis
        self.style = style
    }

    /// A vertical tool palette: one button per tool, `selected` highlighted;
    /// a click on an enabled tool calls `onSelect`.
    public init<Tool: PaletteTool>(
        tools: [Tool], selected: Tool, style: Style = .floating, onSelect: @escaping @MainActor (Tool) -> Void
    ) {
        self.init(tools.map { tool in
            ToolbarAction(
                tool.title, systemImage: tool.systemImage, isSelected: tool == selected,
                unavailableHelp: tool.unavailableHelp, shortcut: tool.shortcut) { onSelect(tool) }
        }, axis: .vertical, style: style)
    }

    public var body: some View {
        let spacing = style == .rail ? SuiteSpacing.xxs : 0
        let stack = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: spacing)) : AnyLayout(VStackLayout(spacing: spacing))
        let palette = stack {
            ForEach(actions) { action in
                // A disabled tool never shows as the selected one.
                let isSelected = action.isSelected && action.isEnabled
                Button(action: action.perform) {
                    Image(systemName: action.systemImage)
                        .symbolVariant(isSelected ? .fill : .none)
                        .foregroundStyle(Self.symbolStyle(action))
                        .frame(width: SuiteSize.toolButton, height: SuiteSize.toolButton)
                        .background(well(isSelected))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!action.isEnabled)
                // After .disabled, so the tooltip still shows on a disabled tool.
                .help(action.help)
                .accessibilityLabel(action.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .suiteControl(action)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.tools")
        .padding(SuiteSpacing.xs)
        if style == .rail {
            palette
        } else {
            palette.suiteGlass(in: Capsule())
        }
    }

    /// The selected tool's tint: a circle in the capsule, a rounded square on the rail.
    @ViewBuilder private func well(_ isSelected: Bool) -> some View {
        if !isSelected {
            Color.clear
        } else if style == .rail {
            RoundedRectangle(cornerRadius: SuiteRadius.small).fill(SuiteColor.selectedWell)
        } else {
            Circle().fill(SuiteColor.accent.opacity(0.15))
        }
    }

    /// Accent when selected, primary when enabled, tertiary (dimmed) when not;
    /// set here because a plain button style does not dim reliably everywhere.
    private static func symbolStyle(_ action: ToolbarAction) -> AnyShapeStyle {
        guard action.isEnabled else { return AnyShapeStyle(HierarchicalShapeStyle.tertiary) }
        return action.isSelected ? AnyShapeStyle(SuiteColor.accent) : AnyShapeStyle(Color.primary)
    }
}
