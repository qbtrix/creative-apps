// PhotoWindow+File.swift: the file area of a Photo window (photo-documents,
// PV-1): its intents, its route, its hook on the window, the services the
// window runs on, and today's open, Save, Save As and the write they share.
// FileIntent has no case yet: New Image, Open, Save and Save As still route
// through PhotoWindow.perform to the helpers here. Files go through
// ImageIOCodec; the open and save panels are AppKit's. Save writes over the
// open file in its own format; a new image or a HEIC goes to Save As, which
// asks where (PNG or JPEG by the name's extension) and makes that file the
// document. `-PhotoOpenFile <path>` opens a file at launch and
// `-PhotoSaveTo <folder>` makes Save As write `<folder>/<name>.png`.
// PhotoFileArea is the identity; photo-documents keeps its autosave timer, the
// recovery offer, Keep layers?, the failed-save flag, the close prompt and the
// edited dot inside it.
import AppKit
import CoreRaster
import PhotoModel
import SwiftUI
import UniformTypeIdentifiers

/// What the file area can be asked to do (photo-documents adds the cases).
enum FileIntent {}

extension PhotoWindow {
    /// The services a window runs on when no fixture is asked for. PV-0: `.live`.
    /// photo-documents points `recovery` at -PhotoRecoveryDir here.
    nonisolated static func fileServices(_ live: PhotoServices) -> PhotoServices { live }

    func performFile(_ intent: FileIntent) {
        switch intent {}
    }

    func openLaunchFile() {
        guard !Self.launchFileOpened, let path = UserDefaults.standard.string(forKey: "PhotoOpenFile") else { return }
        Self.launchFileOpened = true
        open(URL(fileURLWithPath: path))
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    func open(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let side = ImageIOCodec.pixelSize(of: data).flatMap {
                PhotoWorkspace.decodeLongestSide(width: $0.width, height: $0.height)
            }
            try model.open(data, name: url.lastPathComponent, codec: ImageIOCodec(), longestSide: side)
            documentURL = url
            note = side.map { "Opened at \($0) px on the longest side" }
        } catch {
            problem = "\(url.lastPathComponent) can't be opened. \(Self.reason(error))"
        }
    }

    /// Writes over the open file in its own format; a new image, or a file in
    /// a format Photo doesn't write, is Save As.
    func save() {
        guard model.canvas != nil else { return }
        guard let url = documentURL, let format = ImageFormat(fileName: url.lastPathComponent) else { return saveAs() }
        write(to: url, as: format, quality: exportQuality, saving: true)
    }

    /// Asks where to save, PNG or JPEG by the name's extension; `-PhotoSaveTo` writes a PNG there without asking.
    func saveAs() {
        guard model.canvas != nil else { return }
        if let folder = UserDefaults.standard.string(forKey: "PhotoSaveTo") {
            let url = URL(fileURLWithPath: folder).appending(path: model.fileName(for: .png))
            return write(to: url, as: .png, quality: exportQuality, saving: true)
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = model.fileName(for: ImageFormat(fileName: model.documentName ?? "") ?? .png)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url, as: ImageFormat(fileName: url.lastPathComponent) ?? .png, quality: exportQuality, saving: true)
    }

    /// Saving (Save, Save As) makes `url` the window's file; exporting doesn't.
    func write(to url: URL, as format: ImageFormat, quality: Double, saving: Bool) {
        let (workspace, opened) = (model, documentURL)
        note = saving ? "Saving…" : "Exporting…"
        Task {
            do {
                let data = try await workspace.export(as: format, quality: quality, codec: ImageIOCodec())
                try data.write(to: url, options: .atomic)
                // A file opened meanwhile keeps its own name and URL.
                if saving, documentURL == opened {
                    documentURL = url
                    model.didSave(as: url.lastPathComponent)
                }
                note = "\(saving ? "Saved" : "Exported") \(url.lastPathComponent)"
            } catch {
                note = nil
                problem = "\(url.lastPathComponent) couldn't be written. \(Self.reason(error))"
            }
        }
    }

    static func reason(_ error: Error) -> String {
        switch error {
        case let failure as ImageIOCodec.Failure: failure.description
        case RasterError.invalid(let message): "The image is not valid: \(message)."
        default: error.localizedDescription
        }
    }
}

/// The file area's state, alerts, dialogs and timers over the window.
struct PhotoFileArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}
