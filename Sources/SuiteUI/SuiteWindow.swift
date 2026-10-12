// SuiteWindow.swift: the one window shell every app uses. A NavigationSplitView
// with a sidebar list of SidebarItems, the app's content as the detail, and a
// trailing inspector the user can hide (toolbar button, Option-Command-I).
// The window chrome (toolbar, sidebar, inspector) is system Liquid Glass; the
// content stays flat. Apps pass state in and get selection out through
// `onSelect`; the shell owns only presentation state (inspector visibility).
import SwiftUI

public struct SuiteWindow<Content: View, Inspector: View>: View {
    private let title: String
    private let sidebarTitle: String
    private let items: [SidebarItem]
    private let selection: SidebarItem.ID?
    private let onSelect: @MainActor (SidebarItem.ID) -> Void
    private let actions: [ToolbarAction]
    private let content: Content
    private let inspector: Inspector
    @State private var showsInspector = true

    /// `title` names the open document (or the app when none is open).
    /// `actions` become the window's trailing toolbar items.
    public init(
        title: String, sidebarTitle: String, items: [SidebarItem], selection: SidebarItem.ID?,
        onSelect: @escaping @MainActor (SidebarItem.ID) -> Void, actions: [ToolbarAction] = [],
        @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector
    ) {
        self.title = title
        self.sidebarTitle = sidebarTitle
        self.items = items
        self.selection = selection
        self.onSelect = onSelect
        self.actions = actions
        self.content = content()
        self.inspector = inspector()
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { selection }, set: { id in if let id { onSelect(id) } })) {
                Section(sidebarTitle) {
                    ForEach(items) { SidebarRow($0) }
                }
            }
            .navigationSplitViewColumnWidth(
                min: SuiteSize.sidebarWidth.min, ideal: SuiteSize.sidebarWidth.ideal, max: SuiteSize.sidebarWidth.max)
        } detail: {
            content
                .frame(minWidth: SuiteSize.contentMinimum.width, minHeight: SuiteSize.contentMinimum.height)
                .inspector(isPresented: $showsInspector) {
                    inspector
                        .padding(SuiteSpacing.m)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .inspectorColumnWidth(
                            min: SuiteSize.inspectorWidth.min, ideal: SuiteSize.inspectorWidth.ideal,
                            max: SuiteSize.inspectorWidth.max)
                }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ForEach(actions) { action in
                    Button(action: action.perform) {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .help(action.title)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsInspector.toggle()
                } label: {
                    Label(showsInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing")
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .help(showsInspector ? "Hide Inspector" : "Show Inspector")
            }
        }
        .frame(minWidth: SuiteSize.windowMinimum.width, minHeight: SuiteSize.windowMinimum.height)
    }
}
