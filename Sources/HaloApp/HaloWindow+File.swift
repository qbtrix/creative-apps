// HaloWindow+File.swift: the files area's routes and hook, and the window's
// title. Save and Save As… go where `model.saveTarget` says: `-HaloSaveTo`
// (HaloLaunch) writes that path with no panel, so the journeys skip it; a
// known file is written over; otherwise the route sets `request = .saveAs`
// and `fileScene(_:)` presents the system exporter, clearing the request on
// every exit. A write is atomic and ends in `didSave` or `didFailSave`, whose
// message the failed-save alert shows. The hidden `halo.file` element's value
// is `model.saveStatus` ("Untitled", "Saved", "Edited", "Not saved"); the
// title is `model.windowTitle`. Open… and Open Recent are not built yet
// (#209, HF-10), so they do nothing here and their menu items say why.
import HaloModel
import SwiftUI

extension HaloWindow {
    func filePerform(_ command: HaloCommand) {
        switch command {
        case .save, .saveAs:
            switch model.saveTarget(launchPath: HaloLaunch.current.saveTo, saveAs: command == .saveAs) {
            case .write(let path): writeProject(to: path)
            case .ask: request = .saveAs
            }
        default: break
        }
    }

    func fileScene(_ content: some View) -> some View {
        content
            .background { HaloFileElement(status: model.saveStatus) }
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
            .modifier(HaloSaveAlert(message: model.file.error))
    }

    /// The window's title.
    var fileWindowTitle: String { model.windowTitle }

    /// ponytail: written on the main actor, as Design does; move it off when
    /// large projects make Save stall.
    private func writeProject(to path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            try model.fileData().write(to: url, options: .atomic)
            model.didSave(name: HaloProject.fileName(fromPath: path), path: path)
        } catch {
            model.didFailSave("\(url.lastPathComponent) can't be saved. \(error.localizedDescription)")
        }
    }
}

/// The hidden `halo.file` element: no hits, its value the save status.
private struct HaloFileElement: View {
    let status: String

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("File")
            .accessibilityValue(status)
            .accessibilityIdentifier("halo.file")
    }
}

/// The system alert for a failed save, shown each time the Model's message
/// changes to a new one. Dismissing it keeps the message, so `halo.file`
/// still reads "Not saved"; the alert owns only whether it is showing.
private struct HaloSaveAlert: ViewModifier {
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
            .onChange(of: message) { _, new in shown = new }
    }
}
