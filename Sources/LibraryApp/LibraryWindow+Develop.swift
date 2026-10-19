// LibraryWindow+Develop.swift: the develop area (develop DV-8). The develop
// half of the Photo menu (Copy Settings, Paste Settings, Reset Develop) and
// the Develop tab's actions (LibraryMenu.Develop); the window merges it with
// the crop half. Each action is nil while it can't run. A slider, curve or
// levels sample renders a preview in the loupe; the drag's end, a reset, a
// paste or a sync renders the full picture and redraws the grid thumbnails
// of the photos it changed. Show Original renders the loupe's photo with
// neutral settings (its crop kept) until it is toggled off, an edit lands or
// the loupe steps to another photo. The renders run through the loupe area's
// RenderQueue and land under their token like any loupe render.
import AppKit
import LibraryModel
import SwiftUI

/// Presentation state, like the inspector's tab: the photo Show Original shows.
@Observable final class DevelopAreaState {
    /// The loupe photo shown without its adjustments; nil shows the edit.
    var originalPhotoID: String?
}

extension LibraryWindow {
    var developMenu: LibraryMenu.Photo {
        let canEdit = model.canEditDevelop
        let develop = LibraryMenu.Develop(
            set: canEdit
                ? { (slider: DevelopSlider, value: Double) in
                    model.setDevelop(slider, to: value, coalesceKey: "develop-\(slider.rawValue)")
                    developPreview()
                } : nil,
            setCurve: enabled(canEdit) { (points: [DevelopCurvePoint]) in
                model.setCurve(points, coalesceKey: "develop-curve")
                developPreview()
            },
            setLevels: canEdit
                ? { (field: DevelopLevels.Field, value: Double) in
                    model.setLevels(field, to: value, coalesceKey: "develop-levels")
                    developPreview()
                } : nil,
            endEdit: enabled(canEdit) { developFinish(model.endDevelopDrag()) },
            reset: enabled(canEdit) { (group: DevelopGroup?) in developFinish(model.resetDevelop(group)) },
            resetSlider: enabled(canEdit) { (slider: DevelopSlider) in developFinish(model.resetDevelop(slider)) },
            resetCurve: enabled(canEdit) { developFinish(model.resetCurve()) },
            resetLevels: enabled(canEdit) { developFinish(model.resetLevels()) },
            sync: enabled(model.syncSource != nil) { developFinish(model.syncSettings()) },
            syncTitle: model.syncTitle,
            toggleOriginal: enabled(model.canShowOriginal) { developToggleOriginal() },
            showsOriginal: developShowsOriginal)
        return LibraryMenu.Photo(
            copySettings: enabled(model.canCopySettings) { model.copySettings() },
            pasteSettings: enabled(model.canPasteSettings) { developFinish(model.pasteSettings()) },
            resetDevelop: enabled(canEdit) { developFinish(model.resetDevelop(nil)) },
            develop: develop)
    }

    /// True while the loupe's photo shows without its adjustments; stepping
    /// to another photo ends it.
    private var developShowsOriginal: Bool {
        guard let id = areas.develop.originalPhotoID else { return false }
        return id == model.focusedItemID
    }

    /// A drag's sample: Show Original off, a quick preview in the loupe.
    private func developPreview() {
        if areas.develop.originalPhotoID != nil { areas.develop.originalPhotoID = nil }
        developRender(.preview, original: false)
    }

    /// An edit that ended: the full render, then the changed photos' thumbnails redrawn.
    private func developFinish(_ ids: Set<String>) {
        if areas.develop.originalPhotoID != nil { areas.develop.originalPhotoID = nil }
        developRender(.full, original: false)
        guard !ids.isEmpty else { return }
        let service = model.services.thumbnails
        Task {
            for id in ids { await service.invalidate(id) }
            refreshThumbnails(invalidating: ids)
        }
    }

    /// Show Original on (the photo with neutral settings, its crop kept) or off.
    private func developToggleOriginal() {
        let on = !developShowsOriginal
        areas.develop.originalPhotoID = on ? model.focusedItemID : nil
        developRender(.full, original: on)
    }

    /// The loupe's render through the loupe area's queue, under a new token.
    /// Before the loupe area has listened for results it renders itself.
    private func developRender(_ quality: RenderQuality, original: Bool) {
        guard model.mode == .loupe else { return }
        let state = areas.loupe
        guard state.listening else { return loupeAreaFocusChanged() }
        guard let request = model.loupeRequest(longSide: developLongSide, quality: quality) else { return }
        let settings = original ? DevelopSettings.neutral.setting(crop: request.settings.crop) : request.settings
        let service = model.services.loupe
        let deliver = state.deliver
        let queue = state.queue
        Task.detached(priority: .userInitiated) {
            await queue.submit(token: request.token) {
                let result: Result<RenderedPhoto, LibraryError>
                do {
                    let photo = try await service.render(
                        request.photo, settings: settings, longSide: request.longSide, quality: request.quality)
                    result = .success(photo)
                } catch {
                    result = .failure(error as? LibraryError ?? .renderFailed("the develop edit couldn't be drawn"))
                }
                deliver.yield(LoupeRenderResult(token: request.token, result: result))
            }
        }
    }

    /// The main screen's long side in pixels, the loupe's render size.
    private var developLongSide: Int {
        guard let screen = NSScreen.main else { return 2048 }
        let side = max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor
        return side.isFinite && side >= 1 ? Int(side) : 2048
    }
}
