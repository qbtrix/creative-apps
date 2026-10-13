// DesignWindow.swift: the root of a Design window. It holds the one
// DesignWorkspace (`model`) and the window's presentation state (zoom, the
// viewport, the panel tab, the open file's URL, the status note and the
// alert), turns every DesignIntent into a workspace method or a file panel, and
// publishes a DesignMenu to the menu bar. Only this file calls the workspace's
// methods. The zoom keeps the handle tolerance a constant size on screen, and
// the page is fitted whenever the selected page changes or a file opens.
//
// Files: Open and Save As use AppKit's panels. Save writes to the file the
// window opened or last saved, after finishing any text being typed. New File,
// and Undo or Redo of it (they swap the whole document), clear that URL, so
// Save then asks for a name and never writes a document over a file it doesn't
// match. Two launch arguments let the UI journeys skip the panels:
// `-DesignOpenFile <file path>` opens that file once, in the first window, and
// `-DesignSaveTo <file path>` makes Save and Save As write exactly that path.
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
    @State private var tab = DesignPanelTab.properties
    @State private var documentURL: URL?
    /// The status line's message ("Saved sample.design"); it goes at the next edit.
    @State private var note: String?
    @State private var problem: String?
    @State private var started = false

    /// The launch file opens in the first window only.
    @MainActor private static var launchFileOpened = false

    /// The `.design` extension, as the system types a file on disk. Not one that conforms to JSON: the
    /// type a real `.design` file gets doesn't conform to that, so the open panel would grey it out.
    private static let fileType = UTType(filenameExtension: "design") ?? .data

    var body: some View {
        DesignEditor(
            model: model, documentName: documentURL?.lastPathComponent, note: note, zoom: zoom, tab: tab,
            onTab: { tab = $0 }, onViewport: viewportChanged, onZoom: setZoom, perform: perform
        )
        .navigationTitle(documentURL?.lastPathComponent ?? (model.isOpen ? "Untitled" : "Design"))
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
        case .newFile:
            model.newFile()
            documentURL = nil
        case .open: chooseFile()
        case .openFile(let url): open(url)
        case .save: save()
        case .saveAs: saveAs()
        case .undo:
            let swapsDocument = model.undoActionName == "Undo New File"
            model.undo()
            if swapsDocument { documentURL = nil }
        case .redo:
            let swapsDocument = model.redoActionName == "Redo New File"
            model.redo()
            if swapsDocument { documentURL = nil }
        case .tool(let tool): model.selectTool(tool)
        case .drag(let from, let to, let modifiers):
            model.drag(from: DesignPoint(from), to: DesignPoint(to), modifiers: modifiers)
        case .endDrag: model.endDrag()
        case .nudge(let direction, let shift): model.nudge(direction, shift: shift)
        case .deleteSelection: model.deleteSelection()
        case .deselect: model.deselect()
        case .select(let id): model.selectItem(id)
        // The ids below come from the model's own rows, so a refused call can't happen.
        case .toggleExpanded(let id): try? model.toggleExpanded(id)
        case .addPage: model.addPage()
        case .deletePage: if let id = model.selectedPageID { try? model.deletePage(id) }
        case .setFrame(let id, let x, let y, let width, let height):
            try? model.setNodeFrame(id, x: x, y: y, width: width, height: height)
        case .setFill(let id, let color): try? model.setFill(id, color)
        case .setHidden(let id, let hidden): try? model.setNodeHidden(id, hidden)
        case .setLocked(let id, let locked): try? model.setNodeLocked(id, locked)
        case .editText(let id): try? model.beginTextEdit(id)
        case .textDraft(let text): model.setTextDraft(text)
        case .commitText: model.commitTextEdit()
        case .cancelText: model.cancelTextEdit()
        case .zoomIn: setZoom(ViewerZoom.zoomedIn(from: zoom))
        case .zoomOut: setZoom(ViewerZoom.zoomedOut(from: zoom))
        case .fit: fit()
        }
    }

    // MARK: Zoom

    /// Sets the zoom within the Zoom In and Zoom Out stops, and resizes the handle grab area to match.
    private func setZoom(_ scale: Double) {
        let (lowest, highest) = (ViewerZoom.stops.first ?? 1, ViewerZoom.stops.last ?? 1)
        zoom = scale.isFinite ? Swift.min(Swift.max(scale, lowest), highest) : 1
        model.setHandleTolerance(Double(SuiteSpacing.s) / zoom)
    }

    /// Zooms to show the whole selected page, once the canvas has been laid out.
    private func fit() {
        guard let page = model.selectedPage, viewport != .zero else { return }
        fitPending = false
        let size = CGSize(width: page.frameWidth, height: page.frameHeight)
        let scale = ViewerZoom.fitScale(artboard: size, in: viewport, inset: SuiteSpacing.xxl)
        setZoom(scale > 0 ? scale : 1)
    }

    private func viewportChanged(_ size: CGSize) {
        viewport = size
        if fitPending { fit() }
    }

    // MARK: Files

    /// A window opened by File > New File with no window focused starts with a new file; the
    /// first window opens the launch file when there is one.
    private func start() {
        guard !started else { return }
        started = true
        if launch?.startsNewFile == true {
            perform(.newFile)
        } else {
            openLaunchFile()
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
        open(url)
    }

    /// Replaces the window's document with the file's. A file that can't open leaves it as it was.
    private func open(_ url: URL) {
        do {
            try model.open(Data(contentsOf: url))
            documentURL = url
            fitPending = true
            fit()
        } catch {
            problem = "\(url.lastPathComponent) can't be opened. \(Self.reason(error))"
        }
    }

    /// Writes over the file the window opened or last saved; with none, it is Save As.
    private func save() {
        guard model.isOpen else { return }
        guard let url = Self.launchSaveURL ?? documentURL else { return saveAs() }
        write(to: url)
    }

    private func saveAs() {
        guard model.isOpen else { return }
        if let url = Self.launchSaveURL { return write(to: url) }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.fileType]
        panel.nameFieldStringValue = documentURL?.lastPathComponent ?? "Untitled.design"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    /// ponytail: written on the main thread; a design file is small JSON. Move it off if files grow large.
    private func write(to url: URL) {
        model.commitTextEdit()
        do {
            try model.fileData().write(to: url, options: .atomic)
            documentURL = url
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
