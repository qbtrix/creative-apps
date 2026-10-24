// PhotoWindow+Edit.swift: the edit area of a Photo window (photo-edit,
// PV-2: cut, copy, paste, duplicate, merge down, flatten): its intents, its
// route and its hook on the window. Cut and Copy put what the workspace took
// on the general pasteboard through PhotoPasteboardAdapter and SuiteShell's
// PasteboardBridge (clipboard-interop CB-13); Paste reads the best image
// there, or an SVG drawn to fit the canvas, into the workspace, centered on
// the canvas when it has no place of its own. An edit the workspace refuses shows its reason in the window's
// alert. Duplicate Layer goes straight to the workspace; Merge Down and
// Flatten Image work their pixels out off the main actor and commit on return,
// showing the workspace's "Merging…" over the canvas once they run 100 ms
// (SuiteUI's BusyNote). The workspace refuses with its reason in the status line
// (the Layer menu disables them with that reason first). PhotoEditArea
// watches the general pasteboard's change count and publishes what it holds
// (`photoPasteboard`) for the Edit menu.
import AppKit
import CoreRaster
import PhotoModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// Photo's pasteboard adapter with the app's codecs: ImageIO for PNG and what is pasted, SuiteImageIO for TIFF
/// (the bridge adds one from the PNG until shared-codecs SC-photo builds it), AppKit for drawing an SVG.
let photoPasteboardAdapter = PhotoPasteboardAdapter(
    codec: ImageIOCodec(),
    tiff: { image in
        try SuiteImageIO.encode(PixelBuffer(rgba8: image.rgba8, width: image.width, height: image.height), as: .tiff(bitDepth: 8))
    },
    rasterize: { svg, width, height in
        var rect = NSRect(x: 0, y: 0, width: width, height: height)
        guard let picture = NSImage(data: Data(svg.utf8))?.cgImage(forProposedRect: &rect, context: nil, hints: nil),
            let png = NSBitmapImageRep(cgImage: picture).representation(using: .png, properties: [:])
        else { throw SuiteError.damaged("The pasted vector art couldn't be drawn.") }
        return try ImageIOCodec().decode(png, longestSide: max(width, height))
    })

/// What the edit area can be asked to do (photo-edit adds the cases).
enum EditIntent {
    case cut, copy, paste
    case duplicateLayer, mergeDown, flattenImage
}

extension PhotoWindow {
    func performEdit(_ intent: EditIntent) {
        switch intent {
        // Nothing taken leaves its reason ("Nothing to copy.") in the status line.
        case .cut:
            if let help = model.cutHelp {
                problem = PhotoProblem("Can't cut", help)
            } else if let image = model.cutSelection() {
                PasteboardBridge().write(photoPasteboardAdapter.copy(image))
            }
        case .copy:
            if let help = model.copyHelp {
                problem = PhotoProblem("Can't copy", help)
            } else if let image = model.copySelection() {
                PasteboardBridge().write(photoPasteboardAdapter.copy(image))
            }
        case .paste: pasteFromPasteboard()
        case .duplicateLayer: model.duplicateSelectedLayer()
        case .mergeDown: merge(.mergeDown)
        case .flattenImage: merge(.flatten)
        }
    }

    /// Merge Down or Flatten Image: "Merging…" at once, the pixels off the
    /// main actor (seconds on a big photo), then one step unless the image
    /// changed meanwhile, as Straighten does.
    private func merge(_ job: LayerMergeJob) {
        guard model.beginMerge(job) else { return }
        let workspace = model
        Task {
            let result = await Task.detached(priority: .userInitiated) { workspace.merged(job) }.value
            model.commitMerge(result)
        }
    }

    /// Paste: the pasteboard's image (or SVG, drawn to fit the canvas) as a new layer, or a new image with none open.
    private func pasteFromPasteboard() {
        let image: ClipboardImage
        do {
            image = try photoPasteboardAdapter.paste(PasteboardBridge().offered(), canvas: model.canvas)
        } catch {
            problem = PhotoProblem("Can't paste", error.message)
            return
        }
        if let help = model.pasteHelp(true) {
            problem = PhotoProblem("Can't paste", help)
            return
        }
        model.paste(image, viewCenter: pasteCenter)
    }

    /// The canvas centre in canvas pixels: the window fits the image in view
    /// and keeps no scroll position, so that is where the view looks.
    private var pasteCenter: Mask.Point {
        guard let canvas = model.canvas else { return Mask.Point(x: 0, y: 0) }
        return Mask.Point(x: Double(canvas.width) / 2, y: Double(canvas.height) / 2)
    }
}

/// What the general pasteboard holds, as the Edit menu's Paste needs it.
struct PhotoPasteboardState: Equatable {
    var hasImage = false
    var isEmpty = true

    @MainActor static func read(_ pasteboard: NSPasteboard = .general) -> Self {
        Self(hasImage: photoPasteboardAdapter.pasteRefusal(PasteboardBridge(pasteboard).offered()) == nil,
             isEmpty: (pasteboard.pasteboardItems ?? []).isEmpty)
    }
}

extension FocusedValues {
    /// What the focused Photo window last saw on the general pasteboard.
    var photoPasteboard: PhotoPasteboardState? {
        get { self[PhotoPasteboardKey.self] }
        set { self[PhotoPasteboardKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as PhotoMenuKey.
private struct PhotoPasteboardKey: FocusedValueKey {
    typealias Value = PhotoPasteboardState
}

/// The edit area's state, alerts and dialogs over the window.
struct PhotoEditArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    @State private var pasteboard = PhotoPasteboardState()

    func body(content: Content) -> some View {
        content
            .overlay {
                // `photo.edit.merging`, once a merge has run 100 ms (a quick one shows nothing).
                if let progress = model.progress {
                    BusyNote(progress, identifier: "photo.edit.merging", delay: .milliseconds(100))
                }
            }
            .focusedSceneValue(\.photoPasteboard, pasteboard)
            // Another app can change the pasteboard at any time and says
            // nothing, so its change count is checked four times a second.
            .task {
                var seen: Int?
                while !Task.isCancelled {
                    let count = NSPasteboard.general.changeCount
                    if count != seen {
                        seen = count
                        pasteboard = PhotoPasteboardState.read()
                    }
                    do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                }
            }
    }
}
