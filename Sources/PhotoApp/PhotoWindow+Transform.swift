// PhotoWindow+Transform.swift: the transform area of a Photo window
// (transform PT-2: Free Transform, flips): its intents, its route, Return and
// Escape while a draft is up, and its hook on the window. Begin, Commit and
// Cancel call the workspace's Free Transform methods; every edit a handle,
// row or flip asks for is SuiteKernel's TransformIntent, run as its
// `transform.*` command through Photo's catalog, so the canvas edits the way
// the CLI and an agent do. A refusal from a drag sample beeps (the drag goes
// on); one from Begin, Commit, a row, a flip or Reset shows the window's
// alert with the reason. On PT-1's stubs Begin and Cancel work and every edit
// refuses until PT-5. PhotoTransformArea is the identity until Canvas Size
// (PT-3) presents its sheet from it.
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
        }
    }

    /// Runs one kernel transform through the catalog; a drag's refused sample
    /// beeps, any other refusal opens the alert.
    private func runTransform(_ edit: SuiteKernel.TransformIntent) {
        let (id, params) = edit.command
        do {
            _ = try PhotoWorkspace.catalog.run(id, params: params, on: &model)
        } catch {
            if Self.isDragSample(edit) {
                NSSound.beep()
            } else {
                problem = PhotoProblem("The layer can't be transformed.", error.description)
            }
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

/// The transform area's state, alerts and dialogs over the window.
struct PhotoTransformArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}
