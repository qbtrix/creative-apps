// HaloWindow+File.swift: the files area's routes and hook, and the window's
// title. Save and Save As… go where `model.saveTarget` says: `-HaloSaveTo`
// (HaloLaunch) writes that path with no panel, so the journeys skip it; a
// known file is written over; otherwise the route sets `request = .saveAs`
// and `fileScene(_:)` presents the system exporter, clearing the request on
// every exit. A write is atomic and ends in `didSave` or `didFailSave`.
// Open… sets `request = .open` (the system importer); Open Recent opens its
// path. With unsaved edits both first set `request = .confirmUnsaved(then:)`:
// "Save changes to <title>?" with Save (then go on, unless the save needs the
// panel or fails), Don't Save (go on) and Cancel. An open runs `beginOpen`,
// decodes off the main actor and ends in `finishOpen`; meanwhile
// `halo.file.progress` reads "Opening <name>…". A failed open or save shows
// the Model's message in one system alert; the project stays as it was.
// At launch the window restores Open Recent from the "HaloRecentFiles"
// default (and writes it back on every change) and opens `-HaloOpenFile`
// once. The hidden `halo.file` element's label and value are
// `model.saveStatus` (journeys read the label: XCUITest reads SwiftUI values
// as empty, #262); the title is `model.windowTitle`, and the title bar's
// subtitle (`.navigationSubtitle`) is `model.windowSubtitle`, "Edited" or
// "Not saved" while the work isn't on disk, else empty. SwiftUI offers no hook to confirm a window
// close, so closing is not guarded yet (#1065 asks SuiteWindow for one).
import HaloModel
import SuiteUI
import SwiftUI

extension HaloWindow {
    func filePerform(_ command: HaloCommand) {
        switch command {
        case .save, .saveAs: save(saveAs: command == .saveAs)
        case .open, .openRecent:
            if model.file.unsaved { request = .confirmUnsaved(then: command) } else { openNow(command) }
        default: break
        }
    }

    func fileScene(_ content: some View) -> some View {
        content
            .navigationSubtitle(model.windowSubtitle ?? "")
            .background { HaloFileElement(status: model.saveStatus) }
            .overlay { HaloOpenProgress(model: model) }
            .fileExporter(
                isPresented: Binding(get: { request == .saveAs }, set: { if !$0, request == .saveAs { request = nil } }),
                document: request == .saveAs ? HaloProjectDocument(project: model) : nil,
                contentType: .halo,
                defaultFilename: model.windowTitle
            ) { result in
                request = nil
                switch result {
                case .success(let url): model.didSave(name: HaloProject.fileName(fromPath: url.path), path: url.path)
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
            .alert(
                "Save changes to \(model.windowTitle)?" as String,
                isPresented: Binding(get: { pendingCommand != nil }, set: { if !$0, pendingCommand != nil { request = nil } })
            ) {
                Button("Save") { goOn(saving: true) }
                Button("Don't Save", role: .destructive) { goOn(saving: false) }
                Button("Cancel", role: .cancel) { request = nil }
            }
            .modifier(HaloFileAlert(message: model.file.error))
            .task { launchFiles() }
            .onChange(of: model.recent) { _, recent in Self.storeRecent(recent) }
    }

    /// The window's title.
    var fileWindowTitle: String { model.windowTitle }

    /// The command the unsaved-changes alert holds back.
    private var pendingCommand: HaloCommand? {
        if case .confirmUnsaved(let then) = request { then } else { nil }
    }

    /// Writes where `saveTarget` says or asks with the panel; true once written.
    @discardableResult private func save(saveAs: Bool) -> Bool {
        switch model.saveTarget(launchPath: HaloLaunch.current.saveTo, saveAs: saveAs) {
        case .write(let path): return writeProject(to: path)
        case .ask:
            request = .saveAs
            return false
        }
    }

    /// The unsaved-changes alert's Save or Don't Save: runs the held command
    /// without asking again, after the alert closes. A Save that needs the
    /// panel or fails stops there.
    private func goOn(saving: Bool) {
        guard let command = pendingCommand else { return }
        request = nil
        if saving, !save(saveAs: false) { return }
        Task { openNow(command) }
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
        }
    }

    /// Open Recent from the defaults; `-HaloOpenFile` once per process.
    private func launchFiles() {
        if let data = UserDefaults.standard.data(forKey: Self.recentKey),
            let recent = try? JSONDecoder().decode([HaloRecentFile].self, from: data) {
            model.setRecent(recent)
        }
        guard !HaloLaunchFile.opened, let path = HaloLaunch.current.openFile else { return }
        HaloLaunchFile.opened = true
        openFile(at: path)
    }

    private static let recentKey = "HaloRecentFiles"

    private static func storeRecent(_ recent: [HaloRecentFile]) {
        guard let data = try? JSONEncoder().encode(recent) else { return }
        UserDefaults.standard.set(data, forKey: recentKey)
    }

    /// ponytail: written on the main actor, as Design does; move it off when
    /// large projects make Save stall.
    private func writeProject(to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            try model.fileData().write(to: url, options: .atomic)
            model.didSave(name: HaloProject.fileName(fromPath: path), path: path)
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

/// `halo.file.progress`: a spinner and "Opening <name>…" over the window from
/// `beginOpen` until `finishOpen`; nothing otherwise. The pending file rides
/// at the head of `file.recent` while it opens.
struct HaloOpenProgress: View {
    let model: HaloProject

    var body: some View {
        if model.file.opening {
            let text = "Opening \(model.file.recent.first?.name ?? "project")…"
            GlassPanel {
                HStack(spacing: SuiteSpacing.s) {
                    ProgressView().controlSize(.small)
                    Text(text).font(SuiteFont.body)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityIdentifier("halo.file.progress")
        }
    }
}

/// The hidden `halo.file` element: no hits, its label and value the save
/// status. The label is what XCUITest can read (values read empty, #262).
private struct HaloFileElement: View {
    let status: String

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(status)
            .accessibilityValue(status)
            .accessibilityIdentifier("halo.file")
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
