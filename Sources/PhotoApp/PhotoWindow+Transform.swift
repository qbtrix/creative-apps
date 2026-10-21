// PhotoWindow+Transform.swift: the transform area of a Photo window
// (transform PT-2: Free Transform, flips): its intents, its route, Return and
// Escape while a draft is up, and its hook on the window. Begin, Commit and
// Cancel call the workspace's Free Transform methods; every edit a handle,
// row or flip asks for is SuiteKernel's TransformIntent, run as its
// `transform.*` command through Photo's catalog, so the canvas edits the way
// the CLI and an agent do. A set, turn or scale while a draft is up changes
// only the draft, so it runs on LiveDraftBox's copy (#4247), which goes back
// into the workspace at the handles' release (`endEdit`), before any other
// intent, or once the edits rest. A refusal from a drag sample beeps (the drag goes
// on); one from Begin, Commit, a row, a flip or Reset shows the window's
// alert with the reason. On PT-1's stubs Begin and Cancel work and every edit
// refuses until PT-5. Image > Canvas Size… (PT-3) opens CanvasSizeSheet from
// PhotoTransformArea on the window's `canvasSizeDraft`; OK calls
// `resizeCanvas(width:height:anchor:)`, whose refusal shows the alert (PT-1's
// stub refuses until PT-6).
import AppKit
import PhotoModel
import SuiteKernel
import SwiftUI

/// What the transform area can be asked to do.
enum TransformIntent {
    /// Edit > Free Transform: the draft and its handles go up on the selected layer.
    case begin
    /// Return or Apply: the draft resamples into the layer as one step.
    case commit
    /// Escape or Cancel: the draft goes, no step.
    case cancel
    /// One edit from the handles, the transform rows or a flip, as its catalog command.
    case kernel(SuiteKernel.TransformIntent)
    /// A handle drag ended: its live draft goes back into the workspace (`perform` takes it).
    case endEdit
    /// Image > Canvas Size…: the sheet opens on the image's size, relative.
    case canvasSize
    /// A change in the Canvas Size sheet.
    case canvasSizeDraft(CanvasSizeDraft)
    /// The sheet's OK: the canvas grows or crops about the draft's anchor.
    case resizeCanvas(CanvasSizeDraft)
    /// The sheet's Cancel, or its dismissal.
    case closeCanvasSize
}

extension PhotoWindow {
    func performTransform(_ intent: TransformIntent) {
        switch intent {
        case .begin:
            do { try model.beginTransform() } catch { problem = PhotoProblem("Free Transform can't start.", Self.refusal(error)) }
        case .commit:
            do { try model.commitTransform() } catch { problem = PhotoProblem("The transform can't be applied.", Self.refusal(error)) }
        case .cancel:
            model.cancelTransform()
        case .kernel(let edit):
            runTransform(edit)
        case .endEdit:
            break
        case .canvasSize:
            canvasSizeDraft = model.canvas.map { CanvasSizeDraft(old: $0, relative: true) }
        case .canvasSizeDraft(let draft):
            canvasSizeDraft = draft
        case .resizeCanvas(let draft):
            canvasSizeDraft = nil
            resizeCanvas(draft)
        case .closeCanvasSize:
            canvasSizeDraft = nil
        }
    }

    /// Canvas Size's OK; a refusal opens the alert.
    private func resizeCanvas(_ draft: CanvasSizeDraft) {
        let size = draft.newSize
        do {
            try model.resizeCanvas(width: size.width, height: size.height, anchor: draft.anchor)
        } catch {
            problem = PhotoProblem("The canvas can't be resized to \(size.width) × \(size.height).", Self.refusal(error))
        }
    }

    /// `edit` on LiveDraftBox's copy when it changes only the draft; false for `perform` to take the
    /// copy back and run it on the workspace. The copy goes back once the edits rest. A refusal
    /// beeps or opens the alert, as `runTransform`'s does.
    func editsDraft(_ edit: SuiteKernel.TransformIntent) -> Bool {
        do {
            guard try draftBox.edits(edit, on: model) else { return false }
        } catch {
            refused(edit, error)
        }
        draftBox.rest { takeStroke() }
        return true
    }

    /// Runs one kernel transform through the catalog; a drag's refused sample
    /// beeps, any other refusal opens the alert.
    private func runTransform(_ edit: SuiteKernel.TransformIntent) {
        let (id, params) = edit.command
        do {
            _ = try PhotoWorkspace.catalog.run(id, params: params, on: &model)
        } catch {
            refused(edit, error)
        }
    }

    /// A refused edit: a drag's sample beeps, any other opens the alert.
    private func refused(_ edit: SuiteKernel.TransformIntent, _ error: CatalogError) {
        if Self.isDragSample(edit) {
            NSSound.beep()
        } else {
            problem = PhotoProblem("The layer can't be transformed.", error.description)
        }
    }

    /// Whether `edit` is one sample of a drag (it carries a token).
    private nonisolated static func isDragSample(_ edit: SuiteKernel.TransformIntent) -> Bool {
        switch edit {
        case .set(_, let drag), .rotate(_, let drag), .scale(_, _, _, let drag): drag != nil
        case .flip, .reset: false
        }
    }

    /// A Free Transform refusal's own words, else the window's reason for the
    /// error (main-actor: it calls the window's `reason`).
    // view-static: main-actor
    private static func refusal(_ error: Error) -> String {
        (error as? PhotoRefusal)?.message ?? reason(error)
    }

    /// Return: commits the draft; false when none is up.
    func confirmTransform() -> Bool {
        guard model.transformDraft != nil else { return false }
        performTransform(.commit)
        return true
    }

    /// Escape: cancels the draft; false when none is up.
    func dismissTransform() -> Bool {
        guard model.transformDraft != nil else { return false }
        model.cancelTransform()
        return true
    }
}

/// The transform area's state, alerts and dialogs over the window: the
/// Canvas Size sheet while `canvasSize` is set.
struct PhotoTransformArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    /// The Canvas Size sheet's choices; nil while it is closed.
    var canvasSize: CanvasSizeDraft?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { canvasSize != nil }, set: { if !$0 { perform(.transform(.closeCanvasSize)) } })) {
                if let draft = canvasSize {
                    CanvasSizeSheet(
                        draft: draft,
                        onDraft: { perform(.transform(.canvasSizeDraft($0))) },
                        onResize: { perform(.transform(.resizeCanvas($0))) },
                        onCancel: { perform(.transform(.closeCanvasSize)) })
                }
            }
    }
}
