// PhotoWindow+File.swift: the file area of a Photo window (photo-documents,
// PV-1): its intents, its route, its hook on the window, the services the
// window runs on, and open, Save, Save As and the writes they share. New
// Image, Open, Save and Save As route through PhotoWindow.perform to the
// helpers here; Keep layers?' choices and Clear Menu are FileIntents. Save
// goes where `model.saveAction` says: a document is written over its `.ora`
// (PhotoPackageIO, the snapshot taken off the main actor), a flat image over
// its file, a flat file whose image has layers asks "Keep layers?" (Save as
// Photo Document writes `<name>.ora` beside it, or in `-PhotoSaveTo`'s
// folder, and makes that the file; Flatten writes the flat file; an NSAlert
// sheet whose buttons carry `photo.file.keep-layers.*`, its words from
// PhotoKeepLayers), and a new
// or read-only image is Save As (the panel offers .ora, PNG and JPEG;
// `-PhotoSaveTo <folder>` writes `<name>.ora` there when the image needs a
// document, else `<name>.png`). A failed save shows "The image couldn't be
// saved: <reason>." and sets `files.saveFailed` until the image is clean.
// A save leaves no note (the save status says "Saved"); an export notes "Exported <name>".
// Open reads an `.ora` and decodes its PNGs off the main actor, then opens
// the snapshot; a bad document shows its ArchiveError message and the window
// keeps what it had. Flat files open through `openImage`, so Save knows
// their kind. Each successful open and save is noted in Open Recent and,
// through SuiteDocumentsBridge (file-flow PF-4), in the suite's shared
// recents: `.opened` or `.saved`, once each, with the file's suite type.
// A document save that lands first publishes the file's thumbnail, off the
// main actor, to the previews the bridge holds (shared-thumbnails ST-7).
// `-PhotoOpenFile <path>` opens a file at launch; `-PhotoRecoveryDir
// <folder>` keeps autosaves there. PhotoFileSession is the file state the
// window and PhotoFileArea share. PhotoFileArea
// puts `model.saveStatus` in the environment for the window's
// subtitle and `photo.bar.saved`, keeps the window's edited dot (`isDocumentEdited`) on
// `model.isDirty`, and shows "Saving…" (`photo.file.saving`) or "Opening…"
// (`photo.file.opening`) over the window once `files.working` has run 100 ms.
// It runs the window's PhotoAutosave (D-9): a tick every second, discarded on
// a clean close; the first window offers what a crash left behind in an
// NSAlert sheet (SwiftUI drops alert buttons' identifiers, and journeys find
// `photo.recovery.restore` by its own), and Restore and Discard are
// FileIntents. D-10: PhotoWindowEditedView is the window's hook for Quit and
// Finder opens (PhotoApp.swift). Closing a dirty window asks through SuiteUI's
// `.unsavedChangesGuard` (adopt-kernel-unsaved-prompt UP-8) with Photo's hooks
// (`unsavedHooks`, buttons `photo.close.*`); a window that closes dirty (Don't
// Save) drops its autosave.
import AppKit
import CoreRaster
import Observation
import PhotoModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI
import UniformTypeIdentifiers

/// What the file area can be asked to do.
enum FileIntent {
    /// Keep layers?: Save as Photo Document.
    case saveDocument
    /// Keep layers?: Flatten into the open file's format.
    case flatten(ImageFormat)
    /// Open Recent > Clear Menu.
    case clearRecent
    /// The launch offer: Restore its image into the window.
    case restore(RecoveryOffer)
    /// The launch offer: Discard what the crash left behind.
    case discardRecovery
    /// The home's New Photo (#3648): a new white image of this size.
    case newImage(width: Int, height: Int)
    /// A live command ran on a copy of the image (EM-3): the window becomes it.
    case adoptLive(PhotoWorkspace)
}

/// Long file work running off the main actor, for the window's notes.
enum PhotoFileWork: Sendable {
    case saving, opening

    /// The note on the canvas while this runs.
    var note: String { self == .saving ? "Saving…" : "Opening…" }

    var identifier: String { self == .saving ? "photo.file.saving" : "photo.file.opening" }
}

/// The file state a window and its PhotoFileArea share.
@MainActor @Observable
final class PhotoFileSession {
    /// The flat format "Keep layers?" asks about while it is up; nil when closed.
    var keepLayers: ImageFormat?
    /// The last save failed and the image hasn't been clean since: "Not saved".
    var saveFailed = false
    /// A save or an open is running off the main actor.
    var working: PhotoFileWork?
    /// Saves that landed, so the unsaved prompt's Save knows it did.
    var saves = 0
    /// Open Recent's files, newest first.
    private(set) var recentFiles: [URL] = PhotoFileSession.storedRecent()
    /// The window's autosave, made on its workspace's recovery store when the window appears.
    private(set) var autosave: PhotoAutosave?
    /// The launch's restore offer while it waits for Restore or Discard.
    var recoveryOffer: RecoveryOffer?
    /// Only the first window of a launch looks for what a crash left behind.
    private static var recoveryChecked = false

    /// The window's autosave, made on `store` the first time.
    func startAutosave(_ store: any RecoveryStoring) -> PhotoAutosave {
        if let autosave { return autosave }
        let made = PhotoAutosave(window: UUID().uuidString, delay: PhotoWorkspace.autosaveDelay, store: store)
        autosave = made
        return made
    }

    /// The first window's launch: offers the newest autosave a crash left behind.
    func offerRecovery(_ model: PhotoWorkspace) async {
        guard !Self.recoveryChecked else { return }
        Self.recoveryChecked = true
        recoveryOffer = await startAutosave(model.services.recovery).launch(model: model)
    }

    /// The bridge opens and saves are noted through; nil uses the process's (tests inject one).
    @ObservationIgnored var bridge: SuiteDocumentsBridge?

    /// Photo's bridge on the live suite store (`-SuiteSupportDir` moves it), made on first use.
    static let suiteBridge: SuiteDocumentsBridge = {
        let arguments = ProcessInfo.processInfo.arguments
        let support = SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory())
        return SuiteDocumentsBridge(app: .photo, services: .live(support: support, app: .photo, arguments: arguments))
    }()

    /// Publishes the thumbnail of the document saved at `url` to the bridge's previews, off the main actor (ST-7).
    func publishPreview(of url: URL, archive: any DocumentArchiving) async {
        let (path, thumbnails) = (url.path(percentEncoded: false), (bridge ?? Self.suiteBridge).thumbnails)
        _ = await Task.detached(priority: .utility) {
            await PhotoSavedPreview.publish(documentAt: path, archive: archive, to: thumbnails)
        }.value
    }

    /// Notes `url` in Open Recent: the system's list, Photo's own (an app with
    /// no declared document types may not get the system's), and the suite's
    /// shared recents as `event`, when the suite knows the file's type.
    func noteRecent(_ url: URL, _ event: RecentEvent) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        store(Array(([url] + recentFiles.filter { $0 != url }).prefix(10)))
        let bridge = self.bridge ?? Self.suiteBridge
        guard let type = bridge.registry.type(forExtension: url.pathExtension)?.id else { return }
        let path = url.path(percentEncoded: false)
        bridge.noted(SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .photo,
                                      type: type, displayName: url.lastPathComponent), event)
    }

    func clearRecent() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        store([])
    }

    private nonisolated static let recentKey = "PhotoRecentFiles"

    /// The saved list; Open Recent reads it with no window open.
    nonisolated static func storedRecent() -> [URL] {
        (UserDefaults.standard.stringArray(forKey: recentKey) ?? []).map { URL(fileURLWithPath: $0) }
    }

    private func store(_ urls: [URL]) {
        recentFiles = urls
        UserDefaults.standard.set(urls.map(\.path), forKey: Self.recentKey)
    }
}

extension PhotoWindow {
    /// Photo's `.live` services with the suite's live text (Core Text), so text layers draw their words.
    nonisolated static var liveServices: PhotoServices {
        var services = PhotoServices.live
        services.text = LiveText()
        return services
    }

    /// The services a window runs on when no fixture is asked for: `.live`,
    /// its looks in the suite's PresetStore (`-SuiteSupportDir` moves it, AJ-9), its autosaves in
    /// `-PhotoRecoveryDir`'s folder when one is given.
    nonisolated static func fileServices(_ live: PhotoServices) -> PhotoServices {
        var live = live
        live.looks = PresetStore(
            folder: SuiteLocations.supportFolder(arguments: ProcessInfo.processInfo.arguments, home: NSHomeDirectory()))
        guard let folder = UserDefaults.standard.string(forKey: "PhotoRecoveryDir") else { return live }
        return live.recovering(in: URL(fileURLWithPath: folder, isDirectory: true))
    }

    /// The last save failed and the image is still edited (D-8's "Not saved").
    var saveFailed: Bool { files.saveFailed }

    /// The OpenRaster document type (a dynamic type while the bundle declares
    /// none); empty only if the system refuses the extension.
    static let documentTypes: [UTType] = UTType(filenameExtension: "ora", conformingTo: .data).map { [$0] } ?? []

    func performFile(_ intent: FileIntent) {
        switch intent {
        case .saveDocument:
            files.keepLayers = nil
            guard let folder = Self.saveToFolder ?? documentURL?.deletingLastPathComponent() else { return saveAs() }
            writeDocument(to: folder.appending(path: model.documentFileName))
        case .flatten(let format):
            files.keepLayers = nil
            guard let url = documentURL else { return saveAs() }
            write(to: url, as: format, quality: model.exportOptions.quality, saving: true)
        case .clearRecent: files.clearRecent()
        case .restore(let offer):
            files.recoveryOffer = nil
            restore(offer)
        case .discardRecovery:
            files.recoveryOffer = nil
            files.startAutosave(model.services.recovery).discardLeftBehind()
        case .newImage(let width, let height):
            guard (try? model.newCanvas(width: width, height: height)) != nil else { return }
            documentURL = nil
        case .adoptLive(let result): model.adoptLiveCommand(result)
        }
    }

    /// Restore: decodes the offer's PNGs off the main actor, then opens the
    /// image; a failure keeps the window as it was and drops the bad file.
    private func restore(_ offer: RecoveryOffer) {
        let (autosave, archive) = (files.startAutosave(model.services.recovery), model.services.archive)
        files.working = .opening
        Task {
            do {
                let snapshot = try await PhotoAutosave.decode(offer, archive: archive, codec: ImageIOCodec())
                try autosave.restore(offer, decoded: snapshot, into: &model)
                documentURL = nil
            } catch {
                autosave.discardLeftBehind()  // it holds nothing to keep (packet note 3)
                problem = PhotoProblem("The image can't be restored.", (error as? ArchiveError)?.message ?? Self.reason(error))
            }
            files.working = nil
        }
    }

    func openLaunchFile() {
        guard !Self.launchFileOpened, let path = UserDefaults.standard.string(forKey: "PhotoOpenFile") else { return }
        Self.launchFileOpened = true
        open(URL(fileURLWithPath: path))
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.documentTypes + [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    func open(_ url: URL) {
        if PhotoWorkspace.fileKind(forName: url.lastPathComponent) == .document { return openDocument(url) }
        do {
            let data = try Data(contentsOf: url)
            let side = ImageIOCodec.pixelSize(of: data).flatMap {
                PhotoWorkspace.decodeLongestSide(width: $0.width, height: $0.height)
            }
            try model.openImage(data, name: url.lastPathComponent, codec: ImageIOCodec(), longestSide: side)
            documentURL = url
            files.noteRecent(url, .opened)
            note = side.map { "Opened at \($0) px on the longest side (Photo opens up to \(PhotoWorkspace.maxOpenPixels / (1024 * 1024)) MP)" }
        } catch {
            problem = PhotoProblem("\(url.lastPathComponent) can't be opened.", Self.reason(error))
        }
    }

    /// Reads and decodes the document at `url` off the main actor, then opens
    /// it; a failure leaves the window as it was.
    private func openDocument(_ url: URL) {
        let (archive, name) = (model.services.archive, url.lastPathComponent)
        files.working = .opening
        Task {
            do {
                let package = try await PhotoPackageIO.read(from: url, archive: archive)
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try archive.decode(package, codec: ImageIOCodec())
                }.value
                try model.openDocument(snapshot, name: name)
                documentURL = url
                files.noteRecent(url, .opened)
                note = nil
            } catch let error as ArchiveError {
                problem = PhotoProblem("\(name) can't be opened.", error.message)
            } catch {
                problem = PhotoProblem("\(name) can't be opened.", Self.reason(error))
            }
            files.working = nil
        }
    }

    /// File > Save, routed by `model.saveAction`.
    func save() {
        guard model.canvas != nil else { return }
        switch model.saveAction {
        case .writeDocument:
            guard let url = documentURL else { return saveAs() }
            writeDocument(to: url)
        case .writeImage(let format):
            guard let url = documentURL else { return saveAs() }
            write(to: url, as: format, quality: model.exportOptions.quality, saving: true)
        case .askKeepLayers(let format): files.keepLayers = format
        case .saveAs: saveAs()
        }
    }

    /// Asks where to save: a document for a name ending in .ora, else PNG or
    /// JPEG by the extension. `-PhotoSaveTo` writes there without asking.
    func saveAs() {
        guard model.canvas != nil else { return }
        if let folder = Self.saveToFolder {
            if model.needsDocument { return writeDocument(to: folder.appending(path: model.documentFileName)) }
            return write(to: folder.appending(path: model.fileName(for: .png)), as: .png, quality: model.exportOptions.quality, saving: true)
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = Self.documentTypes + [.png, .jpeg]
        panel.nameFieldStringValue = model.needsDocument
            ? model.documentFileName : model.fileName(for: ImageFormat(fileName: model.documentName ?? "") ?? .png)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if PhotoWorkspace.fileKind(forName: url.lastPathComponent) == .document { return writeDocument(to: url) }
        write(to: url, as: ImageFormat(fileName: url.lastPathComponent) ?? .png, quality: model.exportOptions.quality, saving: true)
    }

    /// `-PhotoSaveTo`'s folder, when given.
    private static var saveToFolder: URL? {
        UserDefaults.standard.string(forKey: "PhotoSaveTo").map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Writes the image as a document at `url`: the snapshot and the write
    /// both run off the main actor, then `url` is the window's file.
    private func writeDocument(to url: URL) {
        let (workspace, opened) = (model, documentURL)
        note = "Saving…"
        files.working = .saving
        Task {
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) { try workspace.snapshot() }.value
                try await PhotoPackageIO.write(snapshot, to: url, archive: workspace.services.archive, codec: ImageIOCodec())
                await files.publishPreview(of: url, archive: workspace.services.archive)
                didSave(url, kind: .document, opened: opened)
            } catch {
                didFailSave(error)
            }
        }
    }

    /// Saving (Save, Save As, Flatten) makes `url` the window's file; exporting doesn't.
    func write(to url: URL, as format: ImageFormat, quality: Double, saving: Bool) {
        let (workspace, opened) = (model, documentURL)
        note = saving ? "Saving…" : "Exporting…"
        if saving { files.working = .saving }
        Task {
            do {
                var data = try await workspace.export(as: format, quality: quality, codec: ImageIOCodec())
                if !saving { data = Self.carryingMetadata(data, from: opened) }
                try data.write(to: url, options: .atomic)
                if saving {
                    didSave(url, kind: .image(format), opened: opened)
                } else {
                    model.endExport(.success([url.lastPathComponent]))
                    note = "Exported \(url.lastPathComponent)"
                }
            } catch {
                if saving { return didFailSave(error) }
                model.endExport(.failure(error))
                note = nil
                problem = PhotoProblem("\(url.lastPathComponent) couldn't be written.", Self.reason(error))
            }
        }
    }

    /// A save landed at `url`; a file opened meanwhile keeps its own name and URL.
    private func didSave(_ url: URL, kind: PhotoFileKind, opened: URL?) {
        if documentURL == opened {
            documentURL = url
            model.didSave(as: url.lastPathComponent, kind: kind)
            files.autosave?.didSave(model: model)
            files.saves += 1
        }
        files.saveFailed = false
        files.working = nil
        files.noteRecent(url, .saved)
        note = nil  // the save status `photo.bar.saved` says "Saved"
    }

    private func didFailSave(_ error: Error) {
        let reason = Self.reason(error)
        note = nil
        files.working = nil
        files.saveFailed = true
        problem = PhotoProblem("Not saved", "The image couldn't be saved: \(reason.hasSuffix(".") ? String(reason.dropLast()) : reason).")
    }

    static func reason(_ error: Error) -> String {
        switch error {
        case let failure as ImageIOCodec.Failure: failure.description
        case let failure as ArchiveError: failure.message
        case RasterError.invalid(let message): "The image is not valid: \(message)."
        default: error.localizedDescription
        }
    }
}

/// The file area's state, alerts, dialogs and timers over the window.
struct PhotoFileArea: ViewModifier {
    let model: PhotoWorkspace
    let files: PhotoFileSession
    let perform: PhotoPerform
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .environment(\.photoSaveStatus, model.saveStatus(
                autosaved: files.autosave?.autosaved ?? false, saveFailed: files.saveFailed))
            .background { PhotoWindowEdited(model: model, files: files, perform: perform) }
            .unsavedChangesGuard(PhotoWindowEditedView.unsavedHooks(model: { model }, files: files, perform: perform))
            .overlay {
                // A quick save shows nothing: the note waits 100 ms.
                if let work = files.working {
                    BusyNote(work.note, identifier: work.identifier, delay: .milliseconds(100))
                }
            }
            .focusedSceneValue(\.photoRecentFiles, files.recentFiles)
            // Keep layers? as a sheet on the window; Cancel (or no window) just closes it.
            .task(id: files.keepLayers) {
                guard let format = files.keepLayers else { return }
                guard let hook = await PhotoWindowEditedView.hook(for: files),
                      let choice = await hook.askToKeepLayers(format, message: model.keepLayersMessage(format: format))
                else {
                    files.keepLayers = nil
                    return
                }
                perform(.file(choice))
            }
            // A clean image has nothing left unsaved, so "Not saved" goes.
            .onChange(of: model.isDirty) {
                if !model.isDirty { files.saveFailed = false }
            }
            .onChange(of: model.revision) { files.autosave?.noteEdit(at: Date.now.timeIntervalSince1970) }
            // Ticks every second with this revision's workspace; the next revision restarts it.
            .task(id: model.revision) {
                let autosave = files.startAutosave(model.services.recovery)
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    await autosave.tick(model: model, now: Date.now.timeIntervalSince1970, codec: ImageIOCodec())
                }
            }
            .task {
                await files.offerRecovery(model)
                guard let offer = files.recoveryOffer, let hook = await PhotoWindowEditedView.hook(for: files) else { return }
                if let choice = await hook.askToRestore(offer) { perform(.file(choice)) } else { files.recoveryOffer = nil }
            }
            .task { if let intent = PhotoOpenQueue.shared.windowAppeared(openWindow) { perform(intent) } }
            // A clean close leaves nothing to recover; a dirty one asked first (Don't Save discards on close).
            .onDisappear { if !model.isDirty { files.autosave?.discard() } }
    }
}

/// The window's hook (PhotoWindowEditedView).
struct PhotoWindowEdited: NSViewRepresentable {
    let model: PhotoWorkspace
    let files: PhotoFileSession
    let perform: PhotoPerform

    func makeNSView(context: Context) -> PhotoWindowEditedView { PhotoWindowEditedView() }

    func updateNSView(_ view: PhotoWindowEditedView, context: Context) { view.update(model, files: files, perform: perform) }
}

/// An invisible view that keeps its window's edited dot on the image's dirty
/// state, drops the autosave of a window that closes dirty, and hands Quit its
/// window's unsaved hooks; it also asks the restore offer for its window.
final class PhotoWindowEditedView: NSView, PhotoUnsavedWindow {
    /// The visible Photo windows' hooks, front to back.
    static var shown: [PhotoWindowEditedView] {
        let views = all.allObjects
        return NSApp.orderedWindows.filter { $0.isVisible }.compactMap { window in views.first { $0.window === window } }
    }

    private static let all = NSHashTable<PhotoWindowEditedView>.weakObjects()
    private(set) var workspace: PhotoWorkspace?
    private(set) var files: PhotoFileSession?
    private(set) var send: PhotoPerform?
    /// The window whose close this view watches.
    private weak var observed: NSWindow?

    var isDirty: Bool { workspace?.isDirty ?? false }
    var isEmpty: Bool { workspace?.canvas == nil }

    func update(_ workspace: PhotoWorkspace, files: PhotoFileSession, perform: @escaping PhotoPerform) {
        self.workspace = workspace
        self.files = files
        send = perform
        attach()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    /// The edited dot, and a watch on the window's close.
    private func attach() {
        guard let window else { return }
        Self.all.add(self)
        window.isDocumentEdited = isDirty
        guard observed !== window else { return }
        if let observed {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: observed)
        }
        observed = window
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: window)
    }

    /// The guard let a dirty window close only after Don't Save, so its autosave goes.
    @objc private func windowWillClose(_ notification: Notification) {
        if isDirty { discardChanges() }
    }

    func prepareToQuit() async {
        guard let workspace, let autosave = files?.autosave else { return }
        await autosave.willQuit(model: workspace, codec: ImageIOCodec())
    }

    /// The window's hook for `files`, once it is in a window; nil after 2 s without one.
    static func hook(for files: PhotoFileSession) async -> PhotoWindowEditedView? {
        for _ in 0..<40 {
            if let hook = all.allObjects.first(where: { $0.files === files && $0.window != nil }) { return hook }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    /// The launch's restore offer as a sheet: Restore (Return), Discard, or nil
    /// for Cancel (Escape), which leaves the autosave for the next launch. An
    /// NSAlert, since SwiftUI drops the identifiers of an alert's buttons.
    func askToRestore(_ offer: RecoveryOffer) async -> FileIntent? {
        guard let window else { return nil }
        let alert = NSAlert()
        alert.messageText = offer.message
        alert.informativeText = RecoveryOffer.informativeText
        alert.addButton(withTitle: "Restore").setAccessibilityIdentifier("photo.recovery.restore")
        let discard = alert.addButton(withTitle: "Discard")
        discard.setAccessibilityIdentifier("photo.recovery.discard")
        discard.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel").setAccessibilityIdentifier("photo.recovery.cancel")
        switch await alert.beginSheetModal(for: window) {
        case .alertFirstButtonReturn: return .restore(offer)
        case .alertSecondButtonReturn: return .discardRecovery
        default: return nil
        }
    }

    /// "Keep layers?" as a sheet: Save as Photo Document (Return), Flatten
    /// into `format`, or nil for Cancel (Escape). An NSAlert, as the restore
    /// offer, so each button keeps its `photo.file.keep-layers.*` identifier.
    func askToKeepLayers(_ format: ImageFormat, message: String) async -> FileIntent? {
        guard let window else { return nil }
        let alert = NSAlert()
        alert.messageText = PhotoKeepLayers.title
        alert.informativeText = message
        for choice in PhotoKeepLayers.choices(format: format) {
            alert.addButton(withTitle: choice.title).setAccessibilityIdentifier(choice.identifier)
        }
        let response = await alert.beginSheetModal(for: window)
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        switch PhotoKeepLayers.answer(forButton: index, format: format) {
        case .saveDocument: return .saveDocument
        case .flatten(let flat): return .flatten(flat)
        case .cancel: return nil
        }
    }

    var unsavedHooks: UnsavedHooks {
        Self.unsavedHooks(model: { [weak self] in self?.workspace }, files: files, perform: send)
    }

    /// The hooks SuiteUI's guard asks with: buttons `photo.close.*`, the image's
    /// name ("Untitled" before its first save, nil with no image), its dirty
    /// state, and Save through the window.
    static func unsavedHooks(
        model: @escaping @MainActor () -> PhotoWorkspace?, files: PhotoFileSession?, perform: PhotoPerform?
    ) -> UnsavedHooks {
        UnsavedHooks(
            idPrefix: "photo",
            documentName: { model().flatMap { $0.canvas == nil ? nil : $0.documentName ?? "Untitled" } },
            isDirty: { model()?.isDirty ?? false },
            save: { await Self.save(files: files, perform: perform) })
    }

    /// Runs Save (maybe Keep layers? or the panel) and waits; true once it landed.
    static func save(files: PhotoFileSession?, perform: PhotoPerform?) async -> Bool {
        guard let files, let perform else { return false }
        let before = files.saves
        perform(.save)
        while files.working != nil || files.keepLayers != nil {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return false }
        }
        return files.saves != before
    }

    /// Save through this window; true once it landed.
    func save() async -> Bool { await Self.save(files: files, perform: send) }

    func discardChanges() { files?.autosave?.discard() }
}

extension FocusedValues {
    /// The focused Photo window's Open Recent files, newest first.
    var photoRecentFiles: [URL]? {
        get { self[PhotoRecentFilesKey.self] }
        set { self[PhotoRecentFilesKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as PhotoMenuKey.
private struct PhotoRecentFilesKey: FocusedValueKey {
    typealias Value = [URL]
}
