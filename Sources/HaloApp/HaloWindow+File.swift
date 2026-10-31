// HaloWindow+File.swift: the files area's routes and hook, and the window's
// title. Save and Save As… go where `model.saveTarget` says: `-HaloSaveTo`
// (HaloLaunch) writes that path with no panel, so the journeys skip it; a
// known file is written over; otherwise the route sets `request = .saveAs`
// and `fileScene(_:)` presents the system exporter, clearing the request on
// every exit. A write is atomic and ends in `didSave` or `didFailSave`.
// Open… sets `request = .open` (the system importer); Open Recent opens its
// path. With unsaved edits both first ask through SuiteUI's
// `UnsavedGuard.proceed` (the window's `unsavedHooks`, buttons `halo.close.*`):
// the kernel's question with Save (then go on, unless the save fails), Don't
// Save (go on) and Cancel. On an untitled project Save opens the exporter and
// the held open stops there. An open runs `beginOpen`,
// decodes off the main actor and ends in `finishOpen`; meanwhile
// `halo.file.progress` reads "Opening <name>…". A failed open or save shows
// the Model's message in one system alert; the project stays as it was.
// Each open and save is noted in the suite's shared recents through
// SuiteDocumentsBridge (`bridge`), whose list for Halo the window hands the
// Model (`updateFileFlow`); the file-flow commands' requests (open, hand off,
// Clear Menu) run here. At launch the window moves the old "HaloRecentFiles"
// default into the suite's recents once and opens `-HaloOpenFile`
// once, and runs every suite hand-off HaloShell's inbox holds (New
// Composition, or an open through Open Recent's path). The hidden `halo.file` element's label and value are
// `model.saveStatus` (journeys read the label: XCUITest reads SwiftUI values
// as empty, #262); the title is `model.windowTitle`, and the title bar's
// subtitle (`.navigationSubtitle`) is `model.windowSubtitle`, "Edited" or
// "Not saved" while the work isn't on disk, else empty. Closing asks through the guard on the window's
// root (HaloWindow.swift).
import AppKit
import HaloModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

extension HaloWindow {
    #if DEBUG
    /// The suite's recents for the hosted-window tests; nil uses HaloShell's.
    @MainActor static var bridgeOverride: SuiteDocumentsBridge?
    /// The last window's `perform`, for the hosted-window tests to drive.
    @MainActor static var shownPerform: ((HaloCommand) -> Void)?
    #endif

    /// The suite's shared recents and hand-offs.
    @MainActor static var bridge: SuiteDocumentsBridge {
        #if DEBUG
        if let bridgeOverride { return bridgeOverride }
        #endif
        return HaloShell.bridge
    }

    func filePerform(_ command: HaloCommand) {
        switch command {
        case .save, .saveAs: save(saveAs: command == .saveAs)
        case .open, .openRecent:
            let hooks = Self.unsavedHooks(model: { model }, perform: perform)
            guard hooks.isDirty() else { return openNow(command) }
            Task { @MainActor in
                if await UnsavedGuard.proceed(hooks, in: NSApp.keyWindow) { openNow(command) }
            }
        default: break
        }
    }

    func fileScene(_ content: some View) -> some View {
        #if DEBUG
        Self.shownPerform = { perform($0) }
        #endif
        return content
            .navigationSubtitle(model.windowSubtitle ?? "")
            .background { ProbeElement("halo.file", label: model.saveStatus, value: model.saveStatus) }
            .overlay { if let note = model.openingNote { BusyNote(note, identifier: "halo.file.progress") } }
            .fileExporter(
                isPresented: Binding(get: { request == .saveAs }, set: { if !$0, request == .saveAs { request = nil } }),
                document: request == .saveAs ? HaloProjectDocument(project: model) : nil,
                contentType: .halo,
                defaultFilename: model.windowTitle
            ) { result in
                request = nil
                switch result {
                case .success(let url):
                    model.didSave(name: HaloProject.fileName(fromPath: url.path), path: url.path)
                    noteSuite(.saved)
                case .failure(let error):
                    model.didFailSave("\(model.windowTitle).halo can't be saved. \(error.localizedDescription)")
                }
            }
            .fileImporter(
                isPresented: Binding(get: { request == .open }, set: { if !$0, request == .open { request = nil } }),
                allowedContentTypes: [.halo]
            ) { result in
                request = nil
                if case .success(let url) = result {
                    openFile(at: url.path, scoped: url.startAccessingSecurityScopedResource() ? url : nil)
                }
            }
            .modifier(HaloFileAlert(message: model.file.error))
            .task { launchFiles() }
            .onChange(of: Self.bridge.items, initial: true) { model.updateFileFlow(recents: Self.bridge.recents(for: .halo)) }
            .onChange(of: model.fileFlow, initial: true) { drainFileRequests() }
            .onChange(of: HaloShell.inbox.pending, initial: true) { for command in HaloShell.inbox.take() { perform(command) } }
    }

    /// The window's title.
    var fileWindowTitle: String { model.windowTitle }

    /// Writes where `saveTarget` says or asks with the panel; true once written.
    @discardableResult private func save(saveAs: Bool) -> Bool {
        switch model.saveTarget(launchPath: HaloLaunch.current.saveTo, saveAs: saveAs) {
        case .write(let path): return writeProject(to: path)
        case .ask:
            request = .saveAs
            return false
        }
    }

    /// Open… or Open Recent with no question asked.
    private func openNow(_ command: HaloCommand) {
        switch command {
        case .open: request = .open
        case .openRecent(let path): openFile(at: path)
        default: break
        }
    }

    /// `beginOpen`, the decode off the main actor, then `finishOpen`.
    func openFile(at path: String, scoped: URL? = nil) {
        model.beginOpen(name: HaloProject.fileName(fromPath: path), path: path)
        let files = model.services.files
        Task {
            let result = await Task.detached { HaloOpenDecoder.decode(path, files: files, scoped: scoped) }.value
            model.finishOpen(result)
            if model.file.path == path, model.file.error == nil { noteSuite(.opened) }
        }
    }

    /// Notes the project on disk in the suite's recents.
    private func noteSuite(_ event: RecentEvent) {
        if let ref = model.suiteDocument { Self.bridge.noted(ref, event) }
    }

    /// Runs what the file-flow commands left for the window. A missing file's
    /// `.forget` needs no call: the suite's list drops it on its next read.
    private func drainFileRequests() {
        for request in model.takeFileRequests() {
            switch request {
            case .open(let path): perform(.openRecent(path))
            case .handOff(let path, let app): Task { await Self.bridge.handOff([.handOff(path: path, app: app)]) }
            case .clearRecent: Task { await Self.bridge.clear(app: .halo) }
            case .forget: continue
            }
        }
    }

    /// The old Open Recent list into the suite's recents, once; `-HaloOpenFile`
    /// once per process.
    private func launchFiles() {
        var stored = UserDefaults.standard.data(forKey: Self.recentKey)
            .flatMap { try? JSONDecoder().decode([HaloFileRef].self, from: $0) }
        let refs = HaloProject.takeOldRecents(&stored), bridge = Self.bridge
        UserDefaults.standard.removeObject(forKey: Self.recentKey)
        // One task, each note awaited, so the oldest is noted first and the newest stays on top.
        Task { for ref in refs { await bridge.note(ref, .opened) } }
        guard !HaloLaunchFile.opened, let path = HaloLaunch.current.openFile else { return }
        HaloLaunchFile.opened = true
        openFile(at: path)
    }

    private static let recentKey = "HaloRecentFiles"

    /// ponytail: written on the main actor, as Design does; move it off when
    /// large projects make Save stall.
    private func writeProject(to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            try model.fileData().write(to: url, options: .atomic)
            model.didSave(name: HaloProject.fileName(fromPath: path), path: path)
            noteSuite(.saved)
            return true
        } catch {
            model.didFailSave("\(url.lastPathComponent) can't be saved. \(error.localizedDescription)")
            return false
        }
    }
}

/// Reads and decodes a project file off the main actor; a file that can't
/// be read is `.damaged` with the system's reason.
private enum HaloOpenDecoder {
    static func decode(
        _ path: String, files: any ProjectFiles, scoped: URL?
    ) -> Result<HaloDocumentState, HaloFileError> {
        defer { scoped?.stopAccessingSecurityScopedResource() }
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            let reason = error.localizedDescription
            return .failure(.damaged(reason.hasSuffix(".") ? String(reason.dropLast()) : reason))
        }
        do {
            return .success(try files.decode(data))
        } catch let error as HaloFileError {
            return .failure(error)
        } catch {
            return .failure(.notAHaloFile)
        }
    }
}

/// Whether this process has opened `-HaloOpenFile` (only the first window does).
@MainActor private enum HaloLaunchFile {
    static var opened = false
}

extension HaloProject {
    /// `halo.file.progress`'s BusyNote text, "Opening <name>…", from `beginOpen`
    /// until `finishOpen`; nil otherwise.
    var openingNote: String? {
        file.opening ? "Opening \(file.pending?.name ?? "project")…" : nil
    }
}

/// The system alert for a failed save or open, shown each time the Model's
/// message is set again (an open clears it at `beginOpen`, so the same
/// failure twice shows twice). Dismissing it keeps the message, so `halo.file`
/// still reads "Not saved"; the alert owns only whether it is showing.
private struct HaloFileAlert: ViewModifier {
    let message: String?
    @State private var shown: String?

    func body(content: Content) -> some View {
        content
            .alert(
                shown ?? "",
                isPresented: Binding(get: { shown != nil }, set: { if !$0 { shown = nil } })
            ) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: message) { _, new in if let new { shown = new } }
    }
}
