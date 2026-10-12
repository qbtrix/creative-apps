// ToolbarGroup.swift: ToolbarAction (one command: title, SF Symbol, selected
// state, handler) and ToolbarGroup, a floating tool palette of icon buttons
// over a canvas. The whole group sits in one glass capsule (one glass shape,
// no glass on glass); the selected tool is a flat accent tint inside it.
// Window toolbar items use the same ToolbarAction through SuiteWindow.
import SwiftUI

public struct ToolbarAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let isSelected: Bool
    public let perform: @MainActor () -> Void

    /// `title` is also the id, the tooltip and the accessibility label, so it
    /// must be unique within a group.
    public init(
        _ title: String, systemImage: String, isSelected: Bool = false,
        perform: @escaping @MainActor () -> Void = {}
    ) {
        self.id = title
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.perform = perform
    }
}

public struct ToolbarGroup: View {
    private let actions: [ToolbarAction]
    private let axis: Axis

    public init(_ actions: [ToolbarAction], axis: Axis = .horizontal) {
        self.actions = actions
        self.axis = axis
    }

    public var body: some View {
        let stack = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        stack {
            ForEach(actions) { action in
                Button(action: action.perform) {
                    Image(systemName: action.systemImage)
                        .symbolVariant(action.isSelected ? .fill : .none)
                        .foregroundStyle(action.isSelected ? Color.accentColor : Color.primary)
                        .frame(width: SuiteSize.toolButton, height: SuiteSize.toolButton)
                        .background(action.isSelected ? Color.accentColor.opacity(0.15) : .clear, in: Circle())
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(action.title)
                .accessibilityLabel(action.title)
                .accessibilityAddTraits(action.isSelected ? .isSelected : [])
            }
        }
        .padding(SuiteSpacing.xs)
        .suiteGlass(in: Capsule())
    }
}
