// DesignWindow.swift: the root of a Design window. It holds the one
// DesignWorkspace (`model`) and the window's presentation state (zoom, the
// viewport, the status note and the alert; the open file's URL lives in the
// workspace), turns every DesignIntent into a workspace method or a file panel, and
// publishes a DesignMenu to the menu bar. Only this file calls the workspace's
// methods. An open text edit is committed, its box fitted to the measured draft,
// before any intent but a draft or a cancel acts (canvas-basics CB-6). The zoom
// keeps the handle tolerance a constant size on screen, and
// the page is fitted whenever the selected page changes or a file opens, and
// refitted as the canvas resizes until the user zooms, through
// EditorDetailLayout so the fitted page and its handles stay clear of the
// floating palette. The window's title is SuiteWindow's (DesignEditor).
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
//
// File > Export… (⇧⌘E) bumps `exportRequest`; DesignExportArea opens its sheet
// on each change and hands its notes to the status line. DesignHistoryArea holds the
// History panel (View > Show History) and the autosave hooks; a jump and a restore come
// back here as workspace methods.
//
// Cut, Copy and Paste (clipboard-interop CB-6): DesignPasteboardAdapter makes the
// representations (own layers, SVG, a PNG at 2x drawn by DesignRasterizer) and
// takes the best one offered; SuiteShell's PasteboardBridge carries them. A plain
// image or SVG lands as a picture centred on the page (the window has no visible
// rect to centre on yet). A refusal (nothing selected, nothing Design can paste)
// goes to the status line. Copy As writes one representation; Paste as Image
// takes only an image or SVG.
//
// Unsaved changes: SuiteUI's `.unsavedChangesGuard` sits on the root with Design's hooks
// (`unsavedHooks`, buttons `design.close.*`): a close of an edited window, and File > New File
// over one, asks Save, Don't Save or Cancel first. Save runs File > Save and lands only when
// the workspace then reads clean, so a cancelled Save panel keeps the document.
//
// Canvas drags and inspector scrubs (D0-8a): the press goes to the workspace,
// then each later sample goes to DesignLiveDrag's copy, which only DesignCanvas
// draws, so the window doesn't run per sample. Mouse-up, or the scrub's end
// run, replays the last one into the workspace as one step (`live.land(into:)`),
// written before the copy is cleared.
//
// `.suiteProbes()` sits on the root (D0-7a), so the window's `suite.controls`
// lists every control the editor registers with its DesignControlID.
import AppKit
import DesignModel
import SuiteKernel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI
import UniformTypeIdentifiers

struct DesignWindow: View, BodyCounted {
    /// What the window starts with; nil starts empty.
    var launch: DesignLaunch?

    @State private var model = DesignWorkspace()
    /// The drag or scrub shown on a copy until it ends; the canvas reads it from the environment.
    @State private var live = DesignLiveDrag()
    /// Playback on the suite's display link; a tick changes nothing this body reads (DesignWindow+Playback.swift).
    @State private var player = DesignPlayer()
    @Environment(\.designRefreshLink) private var makeLink
    /// A test's starting workspace: the window opens it as it is and skips the launch steps.
    private let seeded: Bool
    @State private var zoom = 1.0
    @State private var viewport = CGSize.zero
    /// The page follows the canvas's size: fitted now and again whenever the canvas resizes, as
    /// the split view lays it out a few times on the way up. The user's own zoom ends it.
    @State private var fitting = false
    /// The status line's message ("Saved sample.design"); it goes at the next edit.
    @State private var note: String?
    @State private var problem: DesignFileProblem?
    @State private var started = false
    /// Bumped by File > Export…; DesignExportArea opens its sheet on each change.
    @State private var exportRequest = 0
    /// The rect Zoom to Selection asked to show; the canvas takes it once it has that input (D0-5b).
    @State private var show: DesignRect?
    @Environment(\.openWindow) private var openWindow
    /// Cut, Copy and Paste through the suite's coder; the PNG is drawn here, on the main actor.
    private let pasteboard = DesignPasteboardAdapter(png: { raster in
        try MainActor.assumeIsolated { try DesignRasterizer.png(raster) }
    })

    /// The launch file opens in the first window only.
    @MainActor private static var launchFileOpened = false
    /// The fixture and window size apply to the first window only.
    @MainActor private static var launchOptionsApplied = false

    /// The `.design` extension, as the system types a file on disk. Not one that conforms to JSON: the
    /// type a real `.design` file gets doesn't conform to that, so the open panel would grey it out.
    private static let fileType = UTType(filenameExtension: "design") ?? .data

    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    /// The workspace after the last intent; DesignLiveDragTests reads it.
    static var lastWorkspace: DesignWorkspace?
    /// Opens the last started window's export sheet; RenderBudgetDesignExportTests calls it (no menu bar there).
    // view-static: main-actor
    static var openExport: (@MainActor () -> Void)?
    /// The last started window's intents; RenderBudgetDesignAnimateTests plays through it.
    // view-static: main-actor
    static var lastPerform: DesignPerform?
    #endif

    /// A window for `launch`; `seed` (tests) starts it on that workspace instead, and `live` is its drag box.
    init(launch: DesignLaunch? = nil, seed: DesignWorkspace? = nil, live: DesignLiveDrag = DesignLiveDrag()) {
        self.launch = launch
        seeded = seed != nil
        _model = State(initialValue: seed ?? DesignWorkspace())
        _live = State(initialValue: live)
    }

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        DesignEditor(
            model: model, documentName: model.documentURL?.lastPathComponent, note: note, zoom: zoom,
            onViewport: viewportChanged, onZoom: userZoom, perform: perform
        )
        .focusedSceneValue(\.designMenu, DesignMenu(model: model, perform: perform))
        .onChange(of: model.selectedPageID) {
            fitting = true
            fit()
        }
        .onChange(of: model.pages) { note = nil }
        .alert(
            problem?.title ?? "",
            isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } }),
            presenting: problem
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { shown in
            Text(shown.message)
        }
        .task {
            #if DEBUG
            Self.lastPerform = perform
            #endif
            start()
        }
        // The key window is the one live commands act on (EM-4).
        .suiteLiveWindow(DesignShell.front, read: { DesignHeadless(model) }, write: { perform(.adoptLive($0.workspace)) })
        // A file handed to Design (Finder, the home's Recent, Open In) opens here while the window is empty (#5200).
        .suiteOpenQueue(DesignShell.openQueue, isEmpty: model.takesOpenedFile, open: { open($0) })
        .unsavedChangesGuard(Self.unsavedHooks(model: { model }, perform: perform))
        .modifier(DesignExportArea(model: model, request: exportRequest, onNote: { note = $0 }))
        .modifier(DesignHistoryArea(model: model, jump: { try model.jumpHistory(to: $0) }, restore: { try model.restoreRecovered(from: $0, name: $1) }, onNote: { note = $0 }))
        .environment(\.designLiveDrag, live)
        // The outermost call publishes `suite.perf` and `suite.controls` under -SuitePerfProbe;
        // SuiteWindow's inner one then adds nothing, so the menus' and alert's hosts share one inventory.
        .suiteProbes()
    }

    private func perform(_ intent: DesignIntent) {
        #if DEBUG
        defer { Self.lastWorkspace = model }
        #endif
        // Anything but a transport intent pauses playback first, so it acts at the frame on screen.
        switch intent {
        case .play, .pause, .stop, .playPause, .scrub, .loop: break
        default: if player.isActive { model.setPlayhead(player.halt(stopping: false, live: live)) }
        }
        // An open text edit ends, fitted to its text, before anything else acts (canvas-basics CB-6).
        switch intent {
        case .textDraft, .cancelText: break
        default: commitText()
        }
        switch intent {
        case .newFile: newFile()
        case .open: chooseFile()
        case .save: save()
        case .saveAs: saveAs()
        case .export: exportRequest += 1
        case .undo: model.undo()
        case .redo: model.redo()
        case .tool(let tool): model.selectTool(tool)
        case .drag(let from, let to, let modifiers):
            let start = DesignPoint(from)
            if !live.isLive {
                // The press goes to the workspace, so the selection shows at once.
                model.drag(from: start, to: start, modifiers: modifiers)
                live.begin(from: model)
            }
            live.sample(from: start, to: DesignPoint(to), modifiers: modifiers)
        case .endDrag: endLive { model.endDrag() }
        case .nudge(let direction, let shift): model.nudge(direction, shift: shift)
        case .deleteSelection: model.deleteSelection()
        case .deselect: model.deselect()
        case .enterGroup: model.enterGroup()
        case .exitGroup: model.exitGroup()
        case .select(let id): model.selectItem(id)
        case .toggleSelect(let id): model.toggleSelection(id)
        // The ids below come from the model's own rows, so a refused call can't happen.
        case .setExpanded(let id, let isExpanded): try? model.setExpanded(id, isExpanded)
        case .addPage: model.addPage()
        case .deletePage: if let id = model.selectedPageID { try? model.deletePage(id) }
        case .setFrame(let id, let x, let y, let width, let height):
            try? model.setNodeFrame(id, x: x, y: y, width: width, height: height)
        case .setFill(let id, let color): try? model.setFill(id, color)
        case .fill(let intent): model.runFill(intent)
        case .transform(let intent): model.runTransform(intent)
        case .shape(let intent): model.runShape(intent)
        case .align(let edge): model.alignLayer(edge)
        case .endEditRun: endLive { model.endEditRun() }
        case .setHidden(let id, let hidden): try? model.setNodeHidden(id, hidden)
        case .setLocked(let id, let locked): try? model.setNodeLocked(id, locked)
        case .toggleFlag(let id, let flag): try? model.toggleNodeFlag(id, flag)
        case .editText(let id): try? model.beginTextEdit(id)
        case .textDraft(let text): model.setTextDraft(text)
        case .commitText: break  // committed above
        case .cancelText: model.cancelTextEdit()
        case .zoomIn: userZoom(ZoomMath.zoomedIn(from: zoom))
        case .playPause: perform(player.isPlaying ? .pause : .play)
        case .play:
            guard !model.isStill, !player.isPlaying else { break }
            if player.isActive { model.setPlayhead(player.halt(stopping: false, live: live)) }
            player.play(model, live: live, makeLink: makeLink) { model.setPlayhead($0) }
        case .pause: if player.isPlaying { model.setPlayhead(player.halt(stopping: false, live: live)) }
        case .stop: model.setPlayhead(player.halt(stopping: true, live: live))
        case .scrub(let frame): player.scrub(to: frame, live: live) { model.setPlayhead($0) }
        case .loop(let on): live.playLoops = on
        case .zoomOut: userZoom(ZoomMath.zoomedOut(from: zoom))
        case .fit:
            fitting = true
            fit()
        case .command(let command):
            do { try model.run(command) } catch { note = error.help }
        // The adapter makes and reads the representations; the bridge carries them. A refusal goes to the status line.
        case .copy:
            do { PasteboardBridge().write(try pasteboard.copy(model)) } catch { note = error.help }
        case .cut:
            do {
                let offered = try pasteboard.copy(model)
                _ = try model.cutSelection()
                PasteboardBridge().write(offered)
            } catch { note = error.help }
        case .paste: paste(PasteboardBridge().offered())
        case .copyAs(let format): copyAs(format)
        case .pasteAsImage: paste(PasteboardBridge().offered().filter { Self.pictureTypes.contains($0.type) })
        case .selectAll: model.selectAll()
        case .zoomToSelection: zoomToSelection()
        case .moveLayer(let id, let parent, let index):
            do { try model.moveLayer(id, into: parent, at: index) } catch { note = error.help }
        case .setStyle(let change):
            do {
                try model.setStyle(change)
                if case .textStyle = change { fitStyledText() }
            } catch { note = error.help }
        case .renamePage(let id, let name):
            do { try model.renamePage(id, to: name) } catch {
                // The page ids come from the model's own rows; only the name can be refused.
                if error == .emptyName { note = DesignRefusal.emptyName.help }
                if case .alreadyExists = error { note = DesignRefusal.nameTaken(name).help }
            }
        case .renameLayer(let id, let name):
            // The row ids come from the model's own rows; only the name can be refused.
            do { try model.renameNode(id, to: name) } catch { if error == .emptyName { note = DesignRefusal.emptyName.help } }
        case .setPageSize(let width, let height): model.setPageSize(width: width, height: height)
        case .pick(let point, let toStroke):
            do { try model.pick(at: point, toStroke: toStroke) } catch { note = error.help }
        case .sampleSize(let size): model.setSampleSize(size)
        case .sampleTarget(let toStroke): model.setSampleTarget(toStroke: toStroke)
        case .adoptLive(let result): model.adoptLiveCommand(result)
        }
    }

    /// Ends an open text edit with the draft's measured extent, so the box fits its text in the
    /// commit's step: an auto-width box takes both sides, a fixed-width one wraps at its width and
    /// takes the height. The edited node is always the selected one (DesignTextOverlay).
    private func commitText() {
        guard let id = model.editingTextID else { return }
        let extent = model.selectedNode.flatMap { node in
            node.id == id ? DesignTextFont.measure(model.textDraft, in: node) : nil
        }
        model.commitTextEdit(extent: extent)
    }

    /// Fits each selected text box to its text in the style just set, in that style's step (#3339).
    private func fitStyledText() {
        let texts = model.selectedNodes.filter { $0.kind == .text }
        model.fitTextStyle(Dictionary(texts.map { ($0.id, DesignTextFont.measure($0.text, in: $0)) }) { first, _ in first })
    }

    /// Lands a live drag or scrub in the workspace as one step; with none live, `otherwise`.
    private func endLive(otherwise: () -> Void) {
        guard live.isLive else { return otherwise() }
        let refusal = live.land(into: &model)
        live.clearAfterLanding()
        if let refusal { note = refusal.help }
    }

    /// The types Paste as Image takes: an image or an SVG, never Design's own layers.
    private static let pictureTypes = Set(DesignPasteboardAdapter.pictureTypes)

    /// Pastes the best of `offered`; with nothing Design takes, the coder's sentence.
    private func paste(_ offered: [TypedData]) {
        do { try pasteboard.paste(offered, into: &model, centredOn: nil) } catch { note = error.help }
    }

    /// Copy As: only `format`'s representation of the selection goes on the pasteboard.
    private func copyAs(_ format: CopyAsFormat) {
        let type: SuiteTypeID = switch format {
        case .png: .png
        case .svg: .svg
        case .own: .designLayers
        }
        do { PasteboardBridge().write(try pasteboard.copy(model).filter { $0.type == type }) } catch { note = error.help }
    }

    // MARK: Zoom

    /// Sets the zoom within ZoomMath's range (10% to 3200%), and resizes the handle grab area to match.
    private func setZoom(_ scale: Double) {
        zoom = ZoomMath.clamped(scale.isFinite ? scale : 1)
        model.setHandleTolerance(Double(SuiteSpacing.s) / zoom)
    }

    /// A zoom the user chose (Zoom In, Zoom Out, a pinch): the page stops following the canvas's size.
    private func userZoom(_ scale: Double) {
        fitting = false
        setZoom(scale)
    }

    /// Zooms to show the whole selected page clear of the floating palette, once the canvas has been
    /// laid out. The palette shows every tool while a page is open.
    private func fit() {
        guard let page = model.selectedPage, viewport != .zero else { return }
        let size = CGSize(width: page.frameWidth, height: page.frameHeight)
        setZoom(ZoomMath.fit(document: size, in: viewport, using: paletteFit))
    }

    /// The fit EditorDetail hands Command-0: clear of the floating palette, which shows every tool
    /// while a page is open.
    private var paletteFit: @Sendable (CGSize, CGSize) -> Double {
        let toolCount = DesignTool.allCases.count
        return { viewport, artboard in
            EditorDetailLayout(viewport: viewport, toolCount: toolCount).fitScale(artboard: artboard)
        }
    }

    /// Zooms to fit the selection clear of the palette and keeps its rect for the canvas to
    /// scroll to; a refusal (nothing selected, or not built yet) goes to the status line.
    private func zoomToSelection() {
        guard let rect = model.zoomToSelectionRect, viewport != .zero else {
            note = model.zoomToSelectionHelp
            return
        }
        userZoom(ZoomMath.fit(document: CGSize(width: rect.width, height: rect.height), in: viewport, using: paletteFit))
        show = rect
    }

    private func viewportChanged(_ size: CGSize) {
        viewport = size
        if fitting { fit() }
    }

    // MARK: Files

    /// The unsaved guard's hooks for a window (`design.close.*`): the name is the open file's ("Untitled"
    /// before its first save, nil with nothing open), the dirty state the workspace's DocumentSession, and
    /// Save runs File > Save, landing only when the workspace then reads clean.
    // view-static: main-actor
    static func unsavedHooks(model: @escaping @MainActor () -> DesignWorkspace, perform: @escaping DesignPerform) -> UnsavedHooks {
        UnsavedHooks(
            idPrefix: "design",
            documentName: {
                let workspace = model()
                return workspace.isOpen ? workspace.documentURL?.lastPathComponent ?? "Untitled" : nil
            },
            isDirty: { model().isDirty },
            save: {
                perform(.save)
                return !model().isDirty
            })
    }

    /// File > New File, after the unsaved guard's sheet on the key window lets it go on.
    private func newFile() {
        let hooks = Self.unsavedHooks(model: { model }, perform: perform)
        guard hooks.isDirty() else { return model.newFile() }
        Task { @MainActor in
            if await UnsavedGuard.proceed(hooks, in: NSApp.keyWindow) { model.newFile() }
        }
    }

    /// A window opened by File > New File with no window focused starts with a new file, one
    /// opened for a file opens it, and the first window opens the launch file when there is one.
    private func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        Self.openExport = { perform(.export) }
        #endif
        if seeded {
            fitting = true
            return fit()
        }
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
                fitting = true
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
            fitting = true
            fit()
        } catch {
            problem = .opening(url.lastPathComponent, Self.reason(error))
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
        commitText()
        do {
            try model.fileData().write(to: url, options: .atomic)
            model.didSave(to: url)
            note = "Saved \(url.lastPathComponent)"
        } catch {
            problem = .saving(url.lastPathComponent, Self.reason(error))
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
