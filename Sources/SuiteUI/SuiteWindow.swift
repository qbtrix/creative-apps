// SuiteWindow.swift: the one window shell every app uses. A NavigationSplitView
// with a sidebar list of SidebarSections, the app's content as the detail, and a
// trailing inspector the user can hide (toolbar button, Option-Command-I).
// The window chrome (toolbar, sidebar, inspector) is system Liquid Glass; the
// content stays flat. Apps pass state in and get selection out through
// `onSelect`, `onToggle`, `onMove` and `onRename`; a nil closure turns that
// gesture off. Toolbar actions with `unavailableHelp` show disabled, with the
// reason as their tooltip. The shell owns only presentation state (inspector
// visibility) and tints the content and inspector with the suite's one accent
// (SuiteColor.accent); the sidebar keeps the system's selection style, which
// dims when the window isn't key. The sidebar and inspector carry the accessibility
// identifiers `suite.sidebar` and `suite.inspector`; the UI journeys in
// UITests/ find them by those names. The window opens at SuiteSize.windowLaunch
// and shrinks to SuiteSize.windowMinimum, both derived from the column tokens.
// The window reads its launch arguments once: with `-SuiteGallery <page>` its
// whole body is the SuiteGallery instead (SuiteGallery.swift); the internal
// `galleryPage:` init skips that check, so the gallery's `window` page never
// recurses. The window applies `.suiteProbes()`; its toolbar buttons carry
// identifiers (`suite.inspectorToggle`, and each action's `identifier`).
import SwiftUI

public struct SuiteWindow<Content: View, Inspector: View>: View {
    private let title: String
    private let sections: [SidebarSection]
    private let selection: SidebarItem.ID?
    private let onSelect: @MainActor (SidebarItem.ID) -> Void
    private let onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)?
    private let onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)?
    private let onRename: (@MainActor (SidebarItem.ID, String) -> Void)?
    private let actions: [ToolbarAction]
    private let content: Content
    private let inspector: Inspector
    /// The gallery this window shows instead of the app; nil shows the app.
    let galleryRequest: GalleryRequest?
    @State private var showsInspector = true

    /// `title` names the open document (or the app when none is open).
    /// `actions` become the window's trailing toolbar items. `onToggle` gets a
    /// row toggle click, `onMove` a drag reorder within a section's top-level
    /// rows, `onRename` a double-click rename.
    public init(
        title: String, sections: [SidebarSection], selection: SidebarItem.ID?,
        onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)? = nil,
        onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)? = nil,
        onRename: (@MainActor (SidebarItem.ID, String) -> Void)? = nil,
        actions: [ToolbarAction] = [],
        @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector
    ) {
        self.init(
            galleryPage: SuiteGallery.request(from: ProcessInfo.processInfo.arguments), title: title,
            sections: sections, selection: selection, onSelect: onSelect, onToggle: onToggle, onMove: onMove,
            onRename: onRename, actions: actions, content: content, inspector: inspector)
    }

    /// The window without the launch-argument check: it shows `galleryPage`
    /// when given, else the app. The gallery's `window` page passes nil.
    init(
        galleryPage: GalleryRequest?, title: String, sections: [SidebarSection], selection: SidebarItem.ID?,
        onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)? = nil,
        onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)? = nil,
        onRename: (@MainActor (SidebarItem.ID, String) -> Void)? = nil,
        actions: [ToolbarAction] = [],
        @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector
    ) {
        self.galleryRequest = galleryPage
        self.title = title
        self.sections = sections
        self.selection = selection
        self.onSelect = onSelect
        self.onToggle = onToggle
        self.onMove = onMove
        self.onRename = onRename
        self.actions = actions
        self.content = content()
        self.inspector = inspector()
    }

    /// One sidebar section titled `sidebarTitle`.
    public init(
        title: String, sidebarTitle: String, items: [SidebarItem], selection: SidebarItem.ID?,
        onSelect: @escaping @MainActor (SidebarItem.ID) -> Void, actions: [ToolbarAction] = [],
        @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector
    ) {
        self.init(
            title: title, sections: [SidebarSection(id: sidebarTitle, title: sidebarTitle, items: items)],
            selection: selection, onSelect: onSelect, actions: actions, content: content, inspector: inspector)
    }

    public var body: some View {
        Group {
            if let galleryRequest {
                SuiteGallery(galleryRequest)
            } else {
                splitView
            }
        }
        .suiteProbes()
        // The window opens at its ideal size: the launch size the column tokens add up to.
        .frame(
            minWidth: SuiteSize.windowMinimum.width, idealWidth: SuiteSize.windowLaunch.width,
            minHeight: SuiteSize.windowMinimum.height, idealHeight: SuiteSize.windowLaunch.height)
    }

    private var splitView: some View {
        NavigationSplitView {
            List(selection: Binding(get: { selection }, set: { id in if let id { onSelect(id) } })) {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { SidebarNode(item: $0, onToggle: onToggle, onRename: onRename) }
                            .onMove(perform: moveAction(in: section.id))
                    } header: {
                        SidebarSectionHeader(section: section)
                    }
                }
            }
            .listStyle(.sidebar)
            .accessibilityIdentifier("suite.sidebar")
            .navigationSplitViewColumnWidth(
                min: SuiteSize.sidebarWidth.min, ideal: SuiteSize.sidebarWidth.ideal, max: SuiteSize.sidebarWidth.max)
        } detail: {
            content
                // An explicit ideal so the content's own ideal width can't widen the
                // detail column past the window and clip the side columns (#579).
                .frame(
                    minWidth: SuiteSize.contentMinimum.width, idealWidth: SuiteSize.contentIdealWidth,
                    maxWidth: .infinity, minHeight: SuiteSize.contentMinimum.height, maxHeight: .infinity)
                .tint(SuiteColor.accent)
                .inspector(isPresented: $showsInspector) {
                    inspector
                        .padding(SuiteSpacing.m)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("suite.inspector")
                        .tint(SuiteColor.accent)
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
                    .disabled(!action.isEnabled)
                    .help(action.help)
                    .suiteControl(action)
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
                .suiteControl(id: "suite.inspectorToggle", enabled: true, reason: nil)
            }
        }
    }

    /// Drag reorder for one section's rows; nil (reorder off) without `onMove`.
    private func moveAction(in sectionID: SidebarSection.ID) -> ((IndexSet, Int) -> Void)? {
        guard let onMove else { return nil }
        return { from, to in onMove(sectionID, from, to) }
    }
}
