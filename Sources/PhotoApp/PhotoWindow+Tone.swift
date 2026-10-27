// PhotoWindow+Tone.swift: the tone area of a Photo window (tone-controls
// PT-2): the suite's tone rows in the Adjust panel send a ToneIntent, and its
// route runs the intent's tone.* command on the workspace's catalog, so the
// rows, the menus and the CLI share one path; a refusal opens the alert. A
// row's drag samples (a `.set` with a drag token) run on the window's live
// copy instead, as Free Transform's do (LiveTransformCopy+Kernel.swift), so a
// drag never re-runs the editor; the Adjust panel reads that copy (PT-5).
import PhotoModel
import SuiteImaging
import SuiteKernel
import SwiftUI

extension PhotoWindow {
    func performTone(_ intent: ToneIntent) {
        let (id, params) = intent.command
        if Self.isToneSample(intent) { return runLive(id, params: params) }
        do {
            _ = try PhotoWorkspace.catalog.run(id, params: params, on: &model)
        } catch {
            problem = PhotoProblem("Tone", error.description)
        }
    }

    /// Whether `intent` is one sample of a tone row's drag, which runs on the live copy.
    nonisolated static func isToneSample(_ intent: PhotoIntent) -> Bool {
        if case .tone(let tone) = intent { isToneSample(tone) } else { false }
    }

    private nonisolated static func isToneSample(_ intent: ToneIntent) -> Bool {
        if case .set(_, _, let drag) = intent { drag != nil } else { false }
    }
}
