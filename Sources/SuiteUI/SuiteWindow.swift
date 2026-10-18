// SuiteWindow.swift: the one window shell every app uses. A NavigationSplitView
// with a sidebar list of SidebarSections, the app's content as the detail, and a
// trailing inspector the user can hide (toolbar button, Option-Command-I).
// The window chrome (toolbar, sidebar, inspector) is system Liquid Glass; the
// content stays flat. Apps pass state in and get selection out through
// `onSelect`, `onToggle`, `onMove` and `onRename`; a nil closure turns that
// gesture off. An overload's `onRename` can refuse: it returns the message
// the row shows under the field it keeps open (LL-6). `contextActions` gives
// each sidebar row its right-click menu of ToolbarActions, through the
// environment to SidebarNode; nil, or no actions for a row, gives no menu
// (LL-8a). `expanded` and `onExpand` make a nested group's expansion the
// app's, through the environment too: the disclosure shows the set and a click
// calls onExpand; without onExpand each group keeps its own (LL-9). Toolbar actions with `unavailableHelp` show disabled, with the
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
// identifiers (`suite.sidebarToggle`, which replaces the system's sidebar toggle,
// `suite.inspectorToggle`, and each action's `identifier`).
// The `sidebar:` init takes an app's own list instead of the sections (the
// sections inits put a SuiteSidebarList there); either way the slot is one
// container carrying `suite.sidebar`, so the app's list keeps its own
// identifier inside it. That init skips the -SuiteGallery check too, so a
// gallery page built on it never recurses. `documentActions` (New, Open,
// Save) sit beside the title after the sidebar toggle, `actions` trail. A
// non-nil `subtitle` is the title bar's subtitle (the save state; "" shows
// none); nil leaves it to the caller (Halo sets its own). `inspectorWidth`
// (an editor's panel) is the inspector's minimum and ideal, and takes the
// inspector ideal's place in the window's minimum and launch widths. With
// `-SuiteWindowSize WxH` a SuiteWindowSizer sizes the window (SuiteWindowSizer.swift).
// The toolbar's centered (`.principal`) slot holds the app switcher
// (AppSwitcher.swift) with no shared toolbar glass behind it: the environment's
// `suiteSwitcher`, or AppSwitcherState.placeholder for this process's name.
// The window measures its width (onGeometryChange) and gives the row
// AppSwitcher.toolbarFit for it and its actions' titles (drawn icon only), so
// the row leaves the sidebar toggle, document actions, title, actions and
// inspector toggle their room and none of them goes into the toolbar's
// overflow; in a crowded toolbar the row narrows to its compact step, and
// when even that doesn't fit it shows the current app's item alone.
import SwiftUI

public struct SuiteWindow<Sidebar: View, Content: View, Inspector: View>: View {
    private let title: String
    private let subtitle: String?
    private let documentActions: [ToolbarAction]
    private let actions: [ToolbarAction]
    private let inspectorWidth: CGFloat?
    private let sidebar: Sidebar
    private let content: Content
    private let inspector: Inspector
    /// Each sidebar row's context menu actions; nil gives no row a menu (LL-8a).
    private let contextActions: (@MainActor (SidebarItem.ID) -> [ToolbarAction])?
    /// The groups the app shows open; nil, or no `onExpand`, leaves each group its own (LL-9).
    private let expanded: Set<SidebarItem.ID>?
    /// Gets a group's id and whether a click opens it (LL-9).
    private let onExpand: (@MainActor (SidebarItem.ID, Bool) -> Void)?
    /// The gallery this window shows instead of the app; nil shows the app.
    let galleryRequest: GalleryRequest?
    /// The `-SuiteWindowSize` frame size; nil keeps the window's own size.
    private let launchSize: CGSize?
    @State private var showsInspector = true
    @State private var columns: NavigationSplitViewVisibility = .all
    /// The window's width, for the switcher's spacing; 0 until measured.
    @State private var windowWidth: CGFloat = 0
    /// The app switcher to show; nil shows the placeholder.
    @Environment(\.suiteSwitcher) private var switcher
}

extension SuiteWindow where Sidebar == SuiteSidebarList {
    /// `title` names the open document (or the app when none is open).
    /// `actions` become the window's trailing toolbar items. `onToggle` gets a
    /// row toggle click, `onMove` a drag reorder within a section's top-level
    /// rows, `onRename` a double-click rename. `contextActions` gives a row's
    /// right-click menu; a row it gives no actions has none (LL-8a).
    /// `expanded` with `onExpand` makes the groups' expansion the app's (LL-9).
    public init(
        title: String, subtitle: String? = nil, sections: [SidebarSection], selection: SidebarItem.ID?,
        onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)? = nil,
        onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)? = nil,
        onRename: (@MainActor (SidebarItem.ID, String) -> Void)? = nil,
        contextActions: (@MainActor (SidebarItem.ID) -> [ToolbarAction])? = nil,
        expanded: Set<SidebarItem.ID>? = nil, onExpand: (@MainActor (SidebarItem.ID, Bool) -> Void)? = nil,
        documentActions: [ToolbarAction] = [], actions: [ToolbarAction] = [],
        @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector
    ) {
        self.init(
            galleryPage: SuiteGallery.request(from: ProcessInfo.processInfo.arguments), title: title,
            subtitle: subtitle, sections: sections, selection: selection, onSelect: onSelect, onToggle: onToggle,
            onMove: onMove, onRename: SidebarNode.refusable(onRename), contextActions: contextActions,
            expanded: expanded, onExpand: onExpand, documentActions: documentActions, actions: actions,
            content: content, inspector: inspector)
    }

    /// The same window with a rename the app can refuse: `onRename` returns
    /// nil to accept, or the message the row shows under its open field (LL-6).
    public init(
        title: String, subtitle: String? = nil, sections: [SidebarSection], selection: SidebarItem.ID?,
        onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)? = nil,
        onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)? = nil,
        onRename: @escaping @MainActor (SidebarItem.ID, String) -> String?,
        contextActions: (@MainActor (SidebarItem.ID) -> [ToolbarAction])? = nil,
        expanded: Set<SidebarItem.ID>? = nil, onExpand: (@MainActor (SidebarItem.ID, Bool) -> Void)? = nil,
        documentActions: [ToolbarAction] = [], actions: [ToolbarAction] = [],
        @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector
    ) {
        self.init(
            galleryPage: SuiteGallery.request(from: ProcessInfo.processInfo.arguments), title: title,
            subtitle: subtitle, sections: sections, selection: selection, onSelect: onSelect, onToggle: onToggle,
            onMove: onMove, onRename: onRename, contextActions: contextActions, expanded: expanded,
            onExpand: onExpand, documentActions: documentActions, actions: actions, content: content,
            inspector: inspector)
    }

    /// The window without the launch-argument check: it shows `galleryPage`
    /// when given, else the app. The gallery's `window` page passes nil.
    init(
        galleryPage: GalleryRequest?, title: String, subtitle: String? = nil, sections: [SidebarSection],
        selection: SidebarItem.ID?, onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)? = nil,
        onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)? = nil,
        onRename: (@MainActor (SidebarItem.ID, String) -> String?)? = nil,
        contextActions: (@MainActor (SidebarItem.ID) -> [ToolbarAction])? = nil,
        expanded: Set<SidebarItem.ID>? = nil, onExpand: (@MainActor (SidebarItem.ID, Bool) -> Void)? = nil,
        documentActions: [ToolbarAction] = [], actions: [ToolbarAction] = [],
        @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector
    ) {
        self.init(
            gallery: galleryPage, title: title, subtitle: subtitle, documentActions: documentActions,
            actions: actions, inspectorWidth: nil, contextActions: contextActions, expanded: expanded,
            onExpand: onExpand,
            sidebar: SuiteSidebarList(
                sections: sections, selection: selection, onSelect: onSelect, onToggle: onToggle, onMove: onMove,
                refusableRename: onRename),
            content: content(), inspector: inspector())
    }

    /// One sidebar section titled `sidebarTitle`.
    public init(
        title: String, subtitle: String? = nil, sidebarTitle: String, items: [SidebarItem],
        selection: SidebarItem.ID?, onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        documentActions: [ToolbarAction] = [], actions: [ToolbarAction] = [],
        @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector
    ) {
        self.init(
            title: title, subtitle: subtitle,
            sections: [SidebarSection(id: sidebarTitle, title: sidebarTitle, items: items)],
            selection: selection, onSelect: onSelect, documentActions: documentActions, actions: actions,
            content: content, inspector: inspector)
    }
}

extension SuiteWindow {
    /// An app's own sidebar list: Design's pages and layer tree, Photo's layers.
    public init(
        title: String, subtitle: String? = nil, documentActions: [ToolbarAction] = [],
        actions: [ToolbarAction] = [], inspectorWidth: CGFloat? = nil,
        @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content,
        @ViewBuilder inspector: () -> Inspector
    ) {
        self.init(
            gallery: nil, title: title, subtitle: subtitle, documentActions: documentActions, actions: actions,
            inspectorWidth: inspectorWidth, sidebar: sidebar(), content: content(), inspector: inspector())
    }

    private init(
        gallery: GalleryRequest?, title: String, subtitle: String?, documentActions: [ToolbarAction],
        actions: [ToolbarAction], inspectorWidth: CGFloat?,
        contextActions: (@MainActor (SidebarItem.ID) -> [ToolbarAction])? = nil,
        expanded: Set<SidebarItem.ID>? = nil, onExpand: (@MainActor (SidebarItem.ID, Bool) -> Void)? = nil,
        sidebar: Sidebar, content: Content, inspector: Inspector
    ) {
        self.galleryRequest = gallery
        self.contextActions = contextActions
        self.expanded = expanded
        self.onExpand = onExpand
        self.title = title
        self.subtitle = subtitle
        self.documentActions = documentActions
        self.actions = actions
        self.inspectorWidth = inspectorWidth
        self.sidebar = sidebar
        self.content = content
        self.inspector = inspector
        self.launchSize = SuiteWindowSize.parse(ProcessInfo.processInfo.arguments)
    }

    public var body: some View {
        Group {
            if let galleryRequest {
                SuiteGallery(galleryRequest)
            } else if let subtitle {
                splitView.navigationSubtitle(subtitle)
            } else {
                splitView
            }
        }
        .suiteProbes()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .background {
            if let launchSize { SuiteWindowSizer(size: launchSize) }
        }
        // The window opens at its ideal size: the launch size the column tokens add up to.
        .frame(
            minWidth: SuiteSize.sidebarWidth.ideal + SuiteSize.contentMinimum.width + inspectorColumn.ideal,
            idealWidth: SuiteSize.sidebarWidth.ideal + SuiteSize.contentIdealWidth + inspectorColumn.ideal,
            minHeight: SuiteSize.windowMinimum.height, idealHeight: SuiteSize.windowLaunch.height)
    }

    /// The app's expansion for the sidebar's groups; nil when the window was given neither part (LL-9).
    private var sidebarExpansion: SidebarExpansion? {
        expanded == nil && onExpand == nil ? nil : SidebarExpansion(expanded: expanded, onExpand: onExpand)
    }

    /// The inspector column's widths: `inspectorWidth` as minimum and ideal, else the token.
    private var inspectorColumn: (min: CGFloat, ideal: CGFloat, max: CGFloat) {
        guard let width = inspectorWidth, width > 0 else { return SuiteSize.inspectorWidth }
        return (width, width, max(width, SuiteSize.inspectorWidth.max))
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            sidebar
                .environment(\.sidebarContextActions, contextActions.map { SidebarContextActions($0) })
                .environment(\.sidebarExpansion, sidebarExpansion)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suite.sidebar")
                // The system's sidebar toggle has no accessibility identifier and can't be given one
                // (the app audit, #262); the toolbar's own `suite.sidebarToggle` replaces it.
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(
                    min: SuiteSize.sidebarWidth.min, ideal: SuiteSize.sidebarWidth.ideal, max: SuiteSize.sidebarWidth.max)
        } detail: {
            content
                // An explicit ideal so the content's own ideal width can't widen the
                // detail column past the window and clip the side columns (#579).
                // Both sit detailInspectorAllowance under the content sizes: the
                // detail column adds the inspector to them, and at the full sizes
                // it laid out at 648 pt and ran past the window's edges (#933).
                .frame(
                    minWidth: SuiteSize.contentMinimum.width - SuiteSize.detailInspectorAllowance,
                    idealWidth: SuiteSize.contentIdealWidth - SuiteSize.detailInspectorAllowance,
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
                            min: inspectorColumn.min, ideal: inspectorColumn.ideal, max: inspectorColumn.max)
                }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                let hidden = columns == .detailOnly
                Button {
                    columns = hidden ? .all : .detailOnly
                } label: {
                    Label(hidden ? "Show Sidebar" : "Hide Sidebar", systemImage: "sidebar.leading")
                }
                .help(hidden ? "Show Sidebar" : "Hide Sidebar")
                .suiteControl(id: "suite.sidebarToggle", enabled: true, reason: nil)
            }
            if !documentActions.isEmpty {
                ToolbarItemGroup(placement: .navigation) {
                    ForEach(documentActions) { actionButton($0) }
                }
            }
            ToolbarItem(placement: .principal) {
                let state = switcher ?? AppSwitcherState.placeholder(processName: ProcessInfo.processInfo.processName)
                // The model adds the window's own sidebar and inspector toggles. Below every
                // step the row takes AppSwitcher.compactSpacing, and when even that crowds
                // the actions, the current app's item alone.
                let fit = AppSwitcher.toolbarFit(
                    windowWidth: windowWidth, itemCount: state.items.count,
                    documentActions: documentActions.map { toolbarItem($0) }, actions: actions.map { toolbarItem($0) })
                AppSwitcher(
                    items: state.shownItems(everyItem: fit.showsEveryItem), current: state.current,
                    spacing: fit.spacing, onSelect: state.onSelect)
            }
            // The switcher row draws its own capsule; no toolbar glass sits behind it.
            .sharedBackgroundVisibility(.hidden)
            ToolbarItemGroup(placement: .primaryAction) {
                ForEach(actions) { actionButton($0) }
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

    /// One toolbar action: disabled, with its reason as the tooltip, while it can't act.
    /// Icon only, as `toolbarItem` tells the switcher; the title stays its accessibility label.
    private func actionButton(_ action: ToolbarAction) -> some View {
        Button(action: action.perform) {
            Label(action.title, systemImage: action.systemImage)
        }
        .labelStyle(.iconOnly)
        .disabled(!action.isEnabled)
        .help(action.help)
        .suiteControl(action)
    }

    /// What `action` takes in the toolbar, as `actionButton` draws it (icon only).
    private func toolbarItem(_ action: ToolbarAction) -> SwitcherToolbarItem {
        SwitcherToolbarItem(action.title, showsTitle: false)
    }
}
