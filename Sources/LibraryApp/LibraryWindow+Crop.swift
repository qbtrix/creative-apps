// LibraryWindow+Crop.swift: the crop area (crop CR-5). The crop half of the
// Photo menu: Crop (R; "Done Cropping" while a draft is open, which applies
// it), Return to apply, and Reset Crop, each enabled only when the catalog
// can act (`cropHelp`, `resetCropHelp`), so a disabled item gives its reason.
// `LibraryMenu.Crop` hands the frame overlay and the CROP section their
// values and closures: every closure is nil without a draft. After a change
// the loupe renders again through the loupe area's RenderQueue (crop adds no
// render path of its own); Reset Crop sends a quick `.preview` first, then
// `.full`. A straighten, Auto or a reset inside the draft renders nothing:
// the loupe's picture is the unturned photo, which the loupe turns itself.
// Auto measures that picture off the main actor and sets the draft to the
// leveler's turn. A Straighten step (#6222) changes only `CropAreaState`'s
// live draft, which the loupe and the CROP section read through
// `\.libraryCropLive`, so a step reruns those views, not the window; a
// handle drag or arrow nudge step does the same. The catalog takes the live
// draft once the steps pause for `CropAreaState.settle`, and every other crop
// action takes it first (`cropAreaFlush`). A live draft whose
// base is no longer the catalog's draft is shown nowhere and dropped. Every
// state change is a LibraryCatalog method. The window merges this half with
// the develop half.
// Orientation (orientation-crop OC-9): Rotate Left, Rotate Right and Flip
// Horizontal and Vertical run the catalog's image.rotate-* and image.flip on
// the selection, then redraw the loupe and those thumbnails; the CROP
// section's aspect picker runs crop.set-aspect and crop.swap.
import CoreRaster
import LibraryModel
import SuiteKernel
import SwiftUI

/// The Straighten and handle drag steps the catalog hasn't taken yet (#6222); the catalog holds the draft.
@Observable final class CropAreaState {
    /// A shown step: `draft` and its frame, canvas and frame value, made from the catalog's `base`.
    struct Live {
        let base: CropSettings, draft: CropSettings
        let frame: PixelRect?, canvas: PixelSize?, frameValue: String?
    }

    /// How long the steps pause before the catalog takes the angle.
    static let settle = Duration.milliseconds(250)
    private(set) var live: Live?
    /// The pending commit; a newer step replaces it.
    @ObservationIgnored var commit: Task<Void, Never>?

    func show(_ step: Live?) { live = step }

    /// `crop` with the live step's draft, frame, canvas and frame value while it
    /// was made from `crop`'s draft; `crop` unchanged otherwise.
    func shown(_ crop: LibraryMenu.Crop) -> LibraryMenu.Crop {
        guard let live, crop.draft == live.base else { return crop }
        var shown = crop
        shown.draft = live.draft
        (shown.frame, shown.canvas, shown.frameValue) = (live.frame, live.canvas, live.frameValue)
        return shown
    }
}

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
        /// The aspect picker's pick: its crop.* command on the draft.
        var pick: (@MainActor (CropPick) -> Void)?
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
    /// The window's Straighten steps not yet in the catalog; `shown` on `libraryCrop` gives what to draw.
    @Entry var libraryCropLive = CropAreaState()
}

extension LibraryWindow {
    var cropMenu: LibraryMenu.Photo {
        let cropping = model.cropDraft != nil
        return LibraryMenu.Photo(
            toggleCrop: enabled(model.cropHelp == nil) {
                cropAreaFlush()
                model.toggleCrop()
                cropAreaRender()
            },
            cropTitle: model.cropTitle,
            // Return routes here: nil outside crop mode, so the key goes on to the grid or the loupe.
            applyCrop: enabled(cropping) {
                cropAreaFlush()
                model.applyCrop()
                cropAreaRender()
            },
            resetCrop: enabled(model.resetCropHelp == nil) {
                cropAreaFlush()
                model.resetCrop()
                cropAreaRender(preview: true)
            },
            rotateLeft: cropAreaOrientAction("image.rotate-ccw"),
            rotateRight: cropAreaOrientAction("image.rotate-cw"),
            flipHorizontal: cropAreaOrientAction("image.flip", .object(["axis": .string("horizontal")])),
            flipVertical: cropAreaOrientAction("image.flip", .object(["axis": .string("vertical")])))
    }

    /// Image command `id` on the selection, nil while the catalog says it can't run.
    private func cropAreaOrientAction(_ id: String, _ params: JSONValue = .object([:])) -> LibraryMenu.Action? {
        enabled(LibraryCatalog.catalog.availability(id, on: model).why == nil) { cropAreaOrient(id, params) }
    }

    /// Runs image command `id`, then the loupe's picture and the turned photos' thumbnails again.
    private func cropAreaOrient(_ id: String, _ params: JSONValue) {
        cropAreaFlush()
        let ids = model.developTargets
        _ = try? LibraryCatalog.catalog.run(id, params: params, on: &model)
        cropAreaRender()
        let service = model.services.thumbnails
        Task {
            for id in ids { await service.invalidate(id) }
            refreshThumbnails(invalidating: ids)
        }
    }

    /// The picker's pick on the draft: crop.set-aspect with its aspect and orientation, or crop.swap.
    private func cropAreaPick(_ pick: CropPick) {
        let params: JSONValue = pick.command == CropAspectChoices.aspectCommand
            ? .object(["aspect": .string(pick.aspect.rawValue), "orientation": .string(pick.orientation.rawValue)])
            : .object([:])
        cropAreaFlush()
        _ = try? LibraryCatalog.catalog.run(pick.command, params: params, on: &model)
    }

    /// The overlay's and the CROP section's values and closures; each closure nil without a draft.
    var cropControls: LibraryMenu.Crop {
        // Typed locals: one initializer holding every closure is too much for the type checker.
        let cropping = model.cropDraft != nil
        let artboard: PixelSize? = model.loupeItem.map { model.croppedSize($0) }
        let setAspect: (@MainActor (CropAspect) -> Void)? = enabled(cropping) { (aspect: CropAspect) in
            cropAreaFlush()
            model.setCropAspect(aspect)
        }
        let pick: (@MainActor (CropPick) -> Void)? = enabled(cropping) { (picked: CropPick) in
            cropAreaPick(picked)
        }
        var drag: (@MainActor (CropHandle, Double, Double) -> Void)?
        if cropping {
            drag = { (handle: CropHandle, dx: Double, dy: Double) in
                cropAreaDrag(handle, dx, dy)
            }
        }
        // The loupe turns its picture itself, so an angle needs no render.
        let setAngle: (@MainActor (Double) -> Void)? = enabled(cropping) { (degrees: Double) in
            cropAreaStep(degrees)
        }
        let level: LibraryMenu.Action? = enabled(cropping && model.levelHelp == nil) { () in
            cropAreaLevel()
        }
        let apply: LibraryMenu.Action? = enabled(cropping) { () in
            cropAreaFlush()
            model.applyCrop()
            cropAreaRender()
        }
        let cancel: LibraryMenu.Action? = enabled(cropping) { () in
            cropAreaFlush()
            model.cancelCrop()
            cropAreaRender()
        }
        let reset: LibraryMenu.Action? = enabled(cropping) { () in
            cropAreaFlush()
            model.resetCrop()
        }
        return LibraryMenu.Crop(
            draft: model.cropDraft,
            frame: model.cropFrame, canvas: model.cropCanvas, frameValue: model.cropFrameValue,
            artboard: artboard,
            resetHelp: model.resetCropHelp, levelHelp: model.levelHelp,
            setAspect: setAspect, pick: pick, drag: drag, setAngle: setAngle,
            level: level, apply: apply, cancel: cancel, reset: reset)
    }

    /// A Straighten step: the draft at `degrees` shows at once through
    /// `areas.crop`, and the catalog takes it once the steps pause.
    private func cropAreaStep(_ degrees: Double) {
        // A pending handle drag goes in first, so the turn starts from it.
        if let live = areas.crop.live, live.draft != model.cropDraft(angle: live.draft.angle) { cropAreaFlush() }
        guard let base = model.cropDraft, let draft = model.cropDraft(angle: degrees) else { return }
        cropAreaShow(base: base, draft: draft)
    }

    /// A handle drag or arrow nudge step, from the draft on screen: shown at
    /// once through `areas.crop`, so a step reruns the loupe and the CROP
    /// section, not the window; the catalog takes it once the steps pause.
    private func cropAreaDrag(_ handle: CropHandle, _ dx: Double, _ dy: Double) {
        guard let base = model.cropDraft else { return }
        let live = areas.crop.live
        let shown = live?.base == base ? live?.draft ?? base : base
        guard let draft = model.cropDraft(dragging: handle, dx: dx, dy: dy, from: shown) else { return }
        cropAreaShow(base: base, draft: draft)
    }

    /// `draft`, made from the catalog's `base`, shown now and taken by the catalog after `CropAreaState.settle`.
    private func cropAreaShow(base: CropSettings, draft: CropSettings) {
        let state = areas.crop
        state.show(CropAreaState.Live(
            base: base, draft: draft, frame: model.cropFrame(of: draft), canvas: model.cropCanvas(of: draft),
            frameValue: model.cropFrameValue(of: draft)))
        state.commit?.cancel()
        state.commit = Task {
            try? await Task.sleep(for: CropAreaState.settle)
            if !Task.isCancelled { cropAreaFlush() }
        }
    }

    /// The live Straighten or drag step into the catalog, while the catalog's draft is
    /// still the one it was made from; dropped otherwise.
    func cropAreaFlush() {
        let state = areas.crop
        state.commit?.cancel()
        state.commit = nil
        guard let live = state.live else { return }
        state.show(nil)
        if model.cropDraft == live.base { model.setCropDraft(live.draft) }
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
        cropAreaFlush()
        guard let leveler = model.leveler, let image = model.loupeRender?.image,
              let turned = model.cropDraft?.angle else { return }
        Task {
            let delta = await Task.detached(priority: .userInitiated) { () -> Double? in
                guard let buffer = try? PixelBuffer(
                    rgba8: image.rgba8, width: image.size.width, height: image.size.height) else { return nil }
                return try? leveler.levelAngle(buffer)
            }.value
            // The picture is unturned while cropping, so the level turn is absolute.
            model.levelCrop(by: delta.map { $0 - turned })
        }
    }
}
