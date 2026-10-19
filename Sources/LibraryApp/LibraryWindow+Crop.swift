// LibraryWindow+Crop.swift: the crop area (crop CR-5). The crop half of the
// Photo menu: Crop (R; "Done Cropping" while a draft is open, which applies
// it), Return to apply, and Reset Crop, each enabled only when the catalog
// can act (`cropHelp`, `resetCropHelp`), so a disabled item gives its reason.
// `LibraryMenu.Crop` hands the frame overlay and the CROP section their
// values and closures: every closure is nil without a draft. After a change
// the loupe renders again through the loupe area's RenderQueue (crop adds no
// render path of its own); a straighten or reset sends a quick `.preview`
// first, then `.full`. Auto measures the loupe's current picture off the main
// actor and adds the leveler's turn to the draft. Every state change is a
// LibraryCatalog method. The window merges this half with the develop half.
import CoreRaster
import LibraryModel
import SwiftUI

/// The crop area keeps no window state; the catalog holds the draft.
final class CropAreaState {}

extension LibraryMenu {
    /// What the crop frame overlay and the CROP section read and call.
    struct Crop {
        var draft: CropSettings?
        /// The draft's frame and the straightened photo it sits in, in pixels.
        var frame: PixelRect?, canvas: PixelSize?, frameValue: String?
        /// The loupe photo's size after its stored crop: the artboard outside crop mode.
        var artboard: PixelSize?
        /// Why Reset Crop or Auto can't act; nil when it can.
        var resetHelp: String?, levelHelp: String?
        var setAspect: (@MainActor (CropAspect) -> Void)?
        /// A handle drag or arrow nudge, in photo pixels.
        var drag: (@MainActor (CropHandle, Double, Double) -> Void)?
        var setAngle: (@MainActor (Double) -> Void)?
        var level, apply, cancel, reset: Action?
    }
}

extension EnvironmentValues {
    /// The window's `cropControls`, read by the loupe and the Develop tab
    /// (CR-6); empty, with every closure nil, outside a window.
    @Entry var libraryCrop = LibraryMenu.Crop()
}

extension LibraryWindow {
    var cropMenu: LibraryMenu.Photo {
        let cropping = model.cropDraft != nil
        return LibraryMenu.Photo(
            toggleCrop: enabled(model.cropHelp == nil) {
                model.toggleCrop()
                cropAreaRender()
            },
            cropTitle: model.cropTitle,
            // Return routes here: nil outside crop mode, so the key goes on to the grid or the loupe.
            applyCrop: enabled(cropping) {
                model.applyCrop()
                cropAreaRender()
            },
            resetCrop: enabled(model.resetCropHelp == nil) {
                model.resetCrop()
                cropAreaRender(preview: true)
            })
    }

    /// The overlay's and the CROP section's values and closures; each closure nil without a draft.
    var cropControls: LibraryMenu.Crop {
        // Typed locals: one initializer holding every closure is too much for the type checker.
        let cropping = model.cropDraft != nil
        let artboard: PixelSize? = model.loupeItem.map { model.croppedSize($0) }
        let setAspect: (@MainActor (CropAspect) -> Void)? = enabled(cropping) { (aspect: CropAspect) in
            model.setCropAspect(aspect)
        }
        var drag: (@MainActor (CropHandle, Double, Double) -> Void)?
        if cropping {
            drag = { (handle: CropHandle, dx: Double, dy: Double) in
                model.dragCrop(handle, dx: dx, dy: dy)
            }
        }
        let setAngle: (@MainActor (Double) -> Void)? = enabled(cropping) { (degrees: Double) in
            model.setCropAngle(degrees)
            cropAreaRender(preview: true)
        }
        let level: LibraryMenu.Action? = enabled(cropping && model.levelHelp == nil) { () in
            cropAreaLevel()
        }
        let apply: LibraryMenu.Action? = enabled(cropping) { () in
            model.applyCrop()
            cropAreaRender()
        }
        let cancel: LibraryMenu.Action? = enabled(cropping) { () in
            model.cancelCrop()
            cropAreaRender()
        }
        let reset: LibraryMenu.Action? = enabled(cropping) { () in
            model.resetCrop()
            cropAreaRender(preview: true)
        }
        return LibraryMenu.Crop(
            draft: model.cropDraft,
            frame: model.cropFrame, canvas: model.cropCanvas, frameValue: model.cropFrameValue,
            artboard: artboard,
            resetHelp: model.resetCropHelp, levelHelp: model.levelHelp,
            setAspect: setAspect, drag: drag, setAngle: setAngle,
            level: level, apply: apply, cancel: cancel, reset: reset)
    }

    /// The loupe's picture again for the catalog's current settings (the
    /// draft's angle while cropping, else the stored crop), through the loupe
    /// area's queue; `preview` sends a quick render first.
    private func cropAreaRender(preview: Bool = false) {
        guard model.mode == .loupe else { return }
        if preview { loupeAreaRender(.preview) }
        loupeAreaRender(.full)
    }

    /// Auto: the leveler's turn for the loupe's current picture, measured off
    /// the main actor, added to the draft (nil, no horizon, changes nothing).
    private func cropAreaLevel() {
        guard let leveler = model.leveler, let image = model.loupeRender?.image else { return }
        Task {
            let delta = await Task.detached(priority: .userInitiated) { () -> Double? in
                guard let buffer = try? PixelBuffer(
                    rgba8: image.rgba8, width: image.size.width, height: image.size.height) else { return nil }
                return try? leveler.levelAngle(buffer)
            }.value
            model.levelCrop(by: delta)
            cropAreaRender(preview: true)
        }
    }
}
