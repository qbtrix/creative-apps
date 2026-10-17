// DesignWindow.swift: the root of a Design window. It holds the one
// DesignWorkspace (`model`) and the window's presentation state (zoom, the
// viewport, the status note and the alert; the open file's URL lives in the
// workspace), turns every DesignIntent into a workspace method or a file panel, and
// publishes a DesignMenu to the menu bar. Only this file calls the workspace's
// methods. The zoom keeps the handle tolerance a constant size on screen, and
// the page is fitted whenever the selected page changes or a file opens,
// through EditorDetailLayout so the fitted page and its handles stay clear of
// the floating palette. The window's title is SuiteWindow's (DesignEditor).
//
// Files: Open and Save As use AppKit's panels. Open fills this window only while
// it holds no file (DesignWorkspace.takesOpenedFile); otherwise the chosen file
// opens in a new window, so Open never loses work. Save writes to the file the
// window opened or last saved (DesignWorkspace.documentURL), after finishing any
// text being typed. New File clears that URL, so Save then asks for a name; Undo
// and Redo of New File swap it back with the document they restore, so Save
// always writes the file that document belongs to (#436). Two launch arguments let the UI journeys skip the panels:
// `-DesignOpenFile <file path>` opens that file once, in the first window, and
// `-DesignSaveTo <file path>` makes Save and Save As write exactly that path.
// DesignWindowOptions reads three more: `-DesignServices fake` (every window),
// `-DesignFixture <name>` (a fixture opened unsaved in the first window; an
// unknown name leaves it empty and says so on the status line) and
// `-DesignWindowSize WxH` (the first window's content size).
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import UniformTypeIdentifiers

struct DesignWindow: View {
    /// What the window starts with; nil starts empty.
    var launch: DesignLaunch?

    @State private var model = DesignWorkspace()
    @State private var zoom = 1.0
    @State private var viewport = CGSize.zero
    /// A new page waits to be fitted until the canvas has a size.
    @State private var fitPending = false
    /// The status line's message ("Saved sample.design"); it goes at the next edit.
    @State private var note: String?
    @State private var problem: String?
    @State private var started = false
    /// The rect Zoom to Selection asked to show; the canvas takes it once it has that input (D0-5b).
    @State private var show: DesignRect?
    @Environment(\.openWindow) private var openWindow

    /// The launch file opens in the first window only.
    @MainActor private static var launchFileOpened = false
    /// The fixture and window size apply to the first window only.
    @MainActor private static var launchOptionsApplied = false

    /// The `.design` extension, as the system types a file on disk. Not one that conforms to JSON: the
    /// type a real `.design` file gets doesn't conform to that, so the open panel would grey it out.
    private static let fileType = UTType(filenameExtension: "design") ?? .data

    #if DEBUG
    /// How many times a window's body ran; RenderBudgetDesignTests counts an interaction's.
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        DesignEditor(
            model: model, documentName: model.documentURL?.lastPathComponent, note: note, zoom: zoom,
            onViewport: viewportChanged, onZoom: setZoom, perform: perform
        )
        .focusedSceneValue(\.designMenu, DesignMenu(model: model, perform: perform))
        .onChange(of: model.selectedPageID) {
            fitPending = true
            fit()
        }
        .onChange(of: model.pages) { note = nil }
        .alert(problem ?? "", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .task { start() }
    }

    private func perform(_ intent: DesignIntent) {
        switch intent {
        case .newFile: model.newFile()
        case .open: chooseFile()
        case .save: save()
        case .saveAs: saveAs()
        case .undo: model.undo()
        case .redo: model.redo()
        case .tool(let tool): model.selectTool(tool)
        case .drag(let from, let to, let modifiers):
            model.drag(from: DesignPoint(from), to: DesignPoint(to), modifiers: modifiers)
        case .endDrag: model.endDrag()
        case .nudge(let direction, let shift): model.nudge(direction, shift: shift)
        case .deleteSelection: model.deleteSelection()
        case .deselect: model.deselect()
        case .select(let id): model.selectItem(id)
        case .toggleSelect(let id): model.toggleSelection(id)
        // The ids below come from the model's own rows, so a refused call can't happen.
        case .setExpanded(let id, let isExpanded): try? model.setExpanded(id, isExpanded)
        case .addPage: model.addPage()
        case .deletePage: if let id = model.selectedPageID { try? model.deletePage(id) }
        case .setFrame(let id, let x, let y, let width, let height):
            try? model.setNodeFrame(id, x: x, y: y, width: width, height: height)
        case .setFill(let id, let color): try? model.setFill(id, color)
        case .align(let edge): model.alignLayer(edge)
        case .endEditRun: model.endEditRun()
        case .setHidden(let id, let hidden): try? model.setNodeHidden(id, hidden)
        case .setLocked(let id, let locked): try? model.setNodeLocked(id, locked)
        case .toggleFlag(let id, let flag): try? model.toggleNodeFlag(id, flag)
        case .editText(let id): try? model.beginTextEdit(id)
        case .textDraft(let text): model.setTextDraft(text)
        case .commitText: model.commitTextEdit()
        case .cancelText: model.cancelTextEdit()
        case .zoomIn: setZoom(ViewerZoom.zoomedIn(from: zoom))
        case .zoomOut: setZoom(ViewerZoom.zoomedOut(from: zoom))
        case .fit: fit()
        case .command(let command):
            do { try model.run(command) } catch { note = error.help }
        // The pasteboard bridge for these three is D0-5d's; until it lands they do nothing.
        case .copy, .cut, .paste: break
        case .selectAll: model.selectAll()
        case .zoomToSelection: zoomToSelection()
        case .moveLayer(let id, let parent, let index):
            do { try model.moveLayer(id, into: parent, at: index) } catch { note = error.help }
        case .setStyle(let change):
            do { try model.setStyle(change) } catch { note = error.help }
        case .renamePage(let id, let name):
            do { try model.renamePage(id, to: name) } catch {
                // The page ids come from the model's own rows; only the name can be refused.
                if error == .emptyName { note = DesignRefusal.emptyName.help }
                if case .alreadyExists = error { note = DesignRefusal.nameTaken(name).help }
            }
        }
    }

    // MARK: Zoom

    /// Sets the zoom within the Zoom In and Zoom Out stops, and resizes the handle grab area to match.
    private func setZoom(_ scale: Double) {
        let (lowest, highest) = (ViewerZoom.stops.first ?? 1, ViewerZoom.stops.last ?? 1)
        zoom = scale.isFinite ? Swift.min(Swift.max(scale, lowest), highest) : 1
        model.setHandleTolerance(Double(SuiteSpacing.s) / zoom)
    }

    /// Zooms to show the whole selected page clear of the floating palette, once the canvas has been
    /// laid out. The palette shows every tool while a page is open.
    private func fit() {
        guard let page = model.selectedPage, viewport != .zero else { return }
        fitPending = false
        let size = CGSize(width: page.frameWidth, height: page.frameHeight)
        let layout = EditorDetailLayout(viewport: viewport, toolCount: DesignTool.allCases.count)
        let scale = layout.fitScale(artboard: size)
        setZoom(scale > 0 ? scale : 1)
    }

    /// Zooms to fit the selection clear of the palette and keeps its rect for the canvas to
    /// scroll to; a refusal (nothing selected, or not built yet) goes to the status line.
    private func zoomToSelection() {
        guard let rect = model.zoomToSelectionRect, viewport != .zero else {
            note = model.zoomToSelectionHelp
            return
        }
        let layout = EditorDetailLayout(viewport: viewport, toolCount: DesignTool.allCases.count)
        let scale = layout.fitScale(artboard: CGSize(width: rect.width, height: rect.height))
        setZoom(scale > 0 ? scale : 1)
        show = rect
    }

    private func viewportChanged(_ size: CGSize) {
        viewport = size
        if fitPending { fit() }
    }

    // MARK: Files

    /// A window opened by File > New File with no window focused starts with a new file, one
    /// opened for a file opens it, and the first window opens the launch file when there is one.
    private func start() {
        guard !started else { return }
        started = true
        let options = DesignWindowOptions(arguments: ProcessInfo.processInfo.arguments)
        model.useServices(options.services)
        if let file = launch?.file {
            open(file)
        } else if launch?.startsNewFile == true {
            perform(.newFile)
        } else {
            openLaunchFile()
            applyLaunchOptions(options)
        }
    }

    /// The first window opens `-DesignFixture` and takes `-DesignWindowSize`, floored at the
    /// suite's minimum window size.
    private func applyLaunchOptions(_ options: DesignWindowOptions) {
        guard !Self.launchOptionsApplied else { return }
        Self.launchOptionsApplied = true
        if let name = options.fixture {
            if model.openFixture(name) {
                fitPending = true
                fit()
            } else {
                note = "No fixture named \(name)."
            }
        }
        if let width = options.windowWidth, let height = options.windowHeight {
            let size = CGSize(
                width: Swift.max(width, SuiteSize.windowMinimum.width),
                height: Swift.max(height, SuiteSize.windowMinimum.height))
            // On the next main-actor turn, once the window is on screen.
            Task { @MainActor in (NSApp.keyWindow ?? NSApp.windows.first)?.setContentSize(size) }
        }
    }

    private func openLaunchFile() {
        guard !Self.launchFileOpened, let path = UserDefaults.standard.string(forKey: "DesignOpenFile") else { return }
        Self.launchFileOpened = true
        open(URL(fileURLWithPath: path))
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.fileType]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // A window that holds a file keeps it, edited or not; the chosen file gets its own window.
        if model.takesOpenedFile {
            open(url)
        } else {
            openWindow(id: DesignLaunch.windowID, value: DesignLaunch(file: url))
        }
    }

    /// Replaces the window's document with the file's. A file that can't open leaves it as it was.
    private func open(_ url: URL) {
        do {
            try model.open(Data(contentsOf: url), at: url)
            fitPending = true
            fit()
        } catch {
            problem = "\(url.lastPathComponent) can't be opened. \(Self.reason(error))"
        }
    }

    /// Writes over the file the window opened or last saved; with none, it is Save As.
    private func save() {
        guard model.isOpen else { return }
        guard let url = Self.launchSaveURL ?? model.documentURL else { return saveAs() }
        write(to: url)
    }

    private func saveAs() {
        guard model.isOpen else { return }
        if let url = Self.launchSaveURL { return write(to: url) }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.fileType]
        panel.nameFieldStringValue = model.documentURL?.lastPathComponent ?? "Untitled.design"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    /// ponytail: written on the main thread; a design file is small JSON. Move it off if files grow large.
    private func write(to url: URL) {
        model.commitTextEdit()
        do {
            try model.fileData().write(to: url, options: .atomic)
            model.didSave(to: url)
            note = "Saved \(url.lastPathComponent)"
        } catch {
            problem = "\(url.lastPathComponent) can't be saved. \(Self.reason(error))"
        }
    }

    /// The `-DesignSaveTo` launch argument, when there is one.
    private static var launchSaveURL: URL? {
        UserDefaults.standard.string(forKey: "DesignSaveTo").map { URL(fileURLWithPath: $0) }
    }

    private static func reason(_ error: Error) -> String {
        (error as? DesignFileError)?.reason ?? error.localizedDescription
    }
}
