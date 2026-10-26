// PhotoWindow+Tone.swift: the tone area of a Photo window (tone-controls
// PT-2): the suite's tone rows in the Adjust panel send a ToneIntent, and its
// route runs the intent's tone.* command on the workspace's catalog, so the
// rows, the menus and the CLI share one path; a refusal opens the alert.
import PhotoModel
import SuiteImaging
import SuiteKernel
import SwiftUI

extension PhotoWindow {
    func performTone(_ intent: ToneIntent) {
        let (id, params) = intent.command
        do {
            _ = try PhotoWorkspace.catalog.run(id, params: params, on: &model)
        } catch {
            problem = PhotoProblem("Tone", error.description)
        }
    }
}
