// GalleryShell.swift: the gallery's `shell` page, slice 0 of the AppKit window
// shell spike (paw-workspace docs/design/drafts/2026-10-27-appkit-window-shell.md,
// option B-lite). One NSViewControllerRepresentable hands the page's whole body
// to ShellSplitController, an NSSplitViewController with three stock items: a
// sidebar (SwiftUI List in an NSHostingController, full-height layout), the
// content (CanvasHostView itself, no representable in the hot path) and an
// inspector (SwiftUI in an NSHostingController). Both hosting controllers run
// with `sizingOptions = []`, so a panel never asks the window to re-measure
// (swiftui-rules 4). Widths come from SuiteSize. The toolbar stays SwiftUI's
// `.toolbar` on the root: `suite.sidebarToggle` and `suite.inspectorToggle`
// call the controller's toggleSidebar / toggleInspector through
// ShellSpikeModel, a plain class SwiftUI doesn't observe, so a toggle or a
// divider drag runs 0 page bodies. The page's back button to the index sits in
// the toolbar too (`suite.gallery.back`), because the gallery skips its own
// back row for this page so the sidebar can run the window's full height.
// ShellSpikeModel also counts the page's bodies per instance, never in a
// static, so a budget test reads only its own window (lesson 345).
// Unverified in Apple's docs (read by hand on 2026-10-28, the docs MCPs were
// not connected): whether a hosted split controller's full-height sidebar
// shows under a SwiftUI window's toolbar; the spike's screenshots settle it.
import AppKit
import SwiftUI

enum GalleryShell {
    static let name = "shell"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryShellPage()) }]
}

/// What the shell page owns outside SwiftUI's sight: the split controller its
/// toolbar drives and the page's own body count.
@MainActor final class ShellSpikeModel {
    private(set) var rootBodies = 0
    fileprivate(set) weak var controller: ShellSplitController?

    init() {}

    func countBody() { rootBodies += 1 }
    func toggleSidebar() { controller?.toggleSidebar(nil) }
    func toggleInspector() { controller?.toggleInspector(nil) }
}

/// The split shell in the window, its toolbar on the SwiftUI side.
struct GalleryShellPage: View {
    @State private var model: ShellSpikeModel
    @Environment(\.openGalleryPage) private var open

    init(model: ShellSpikeModel = ShellSpikeModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        let _ = model.countBody()
        ShellSplitHost(model: model)
            .ignoresSafeArea(.container, edges: .top)
            .navigationTitle("Shell")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        open(GalleryIndex.name)
                    } label: {
                        Label("Gallery Index", systemImage: "chevron.backward")
                    }
                    .help("Gallery Index")
                    .suiteControl(id: "suite.gallery.back", enabled: true, reason: nil)
                }
                ToolbarItem(placement: .navigation) {
                    Button {
                        model.toggleSidebar()
                    } label: {
                        Label("Toggle Sidebar", systemImage: "sidebar.leading")
                    }
                    .help("Toggle Sidebar")
                    .suiteControl(id: "suite.sidebarToggle", enabled: true, reason: nil)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.toggleInspector()
                    } label: {
                        Label("Toggle Inspector", systemImage: "sidebar.trailing")
                    }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                    .help("Toggle Inspector")
                    .suiteControl(id: "suite.inspectorToggle", enabled: true, reason: nil)
                }
            }
    }
}

/// The one representable: it makes the controller once and hands it to the model.
struct ShellSplitHost: NSViewControllerRepresentable {
    let model: ShellSpikeModel

    func makeNSViewController(context: Context) -> ShellSplitController {
        let controller = ShellSplitController()
        model.controller = controller
        return controller
    }

    func updateNSViewController(_ controller: ShellSplitController, context: Context) {
        model.controller = controller
    }
}

/// Sidebar, canvas and inspector as stock NSSplitViewItems.
final class ShellSplitController: NSSplitViewController {
    /// The content item's view: the real canvas NSView, with no document.
    let canvas = CanvasHostView(frame: .zero)
    private var placedDividers = false

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let sidebar = NSSplitViewItem(sidebarWithViewController: host(ShellLayersPanel(), id: "suite.sidebar"))
        sidebar.minimumThickness = SuiteSize.sidebarWidth.min
        sidebar.maximumThickness = SuiteSize.sidebarWidth.max
        sidebar.allowsFullHeightLayout = true
        sidebar.canCollapse = true

        let content = NSViewController()
        content.view = canvas
        let contentItem = NSSplitViewItem(viewController: content)
        contentItem.minimumThickness = SuiteSize.contentMinimum.width

        let inspector = NSSplitViewItem(inspectorWithViewController: host(ShellInspector(), id: "suite.inspector"))
        inspector.minimumThickness = SuiteSize.inspectorWidth.min
        inspector.maximumThickness = SuiteSize.inspectorWidth.max
        inspector.canCollapse = true

        splitViewItems = [sidebar, contentItem, inspector]
    }

    /// Full-height sidebars need the window's full-size content view (NSSplitViewItem.allowsFullHeightLayout).
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.styleMask.insert(.fullSizeContentView)
    }

    /// Once the split view has its size: the sidebar and inspector at their ideal widths. With
    /// `sizingOptions = []` the panels have no intrinsic width, so without this they open at their minimum.
    override func viewDidLayout() {
        super.viewDidLayout()
        guard !placedDividers, splitView.bounds.width > 0 else { return }
        placedDividers = true
        splitView.setPosition(SuiteSize.sidebarWidth.ideal, ofDividerAt: 0)
        splitView.setPosition(splitView.bounds.width - SuiteSize.inspectorWidth.ideal - splitView.dividerThickness, ofDividerAt: 1)
    }

    /// A SwiftUI panel in a hosting controller that never sizes the window, named for the journeys.
    private func host<V: View>(_ view: V, id: String) -> NSHostingController<V> {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = []
        controller.view.setAccessibilityIdentifier(id)
        return controller
    }
}

/// The sidebar's rows: a plain List of SidebarRows, selection kept here.
private struct ShellLayersPanel: View {
    private static let items = [
        SidebarItem(id: "layer.title", title: "Title Text", systemImage: "textformat"),
        SidebarItem(id: "layer.shape", title: "Shape", systemImage: "circle"),
        SidebarItem(id: "layer.background", title: "Background", systemImage: "rectangle"),
    ]
    @State private var selection: String? = "layer.title"

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(Self.items) { SidebarRow($0).tag($0.id) }
            } header: {
                SidebarSectionHeader(section: SidebarSection(id: "layers", title: "Layers", items: []))
            }
        }
        .listStyle(.sidebar)
    }
}

/// The inspector: a header card at the top, the rest empty.
private struct ShellInspector: View {
    var body: some View {
        InspectorHeader("Shell", facts: [InspectorFact("Sidebar", "AppKit"), InspectorFact("Canvas", "CanvasHostView")])
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
