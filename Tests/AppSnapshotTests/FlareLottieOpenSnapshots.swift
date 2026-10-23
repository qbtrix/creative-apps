// FlareLottieOpenSnapshots.swift (lottie-open LO-4; docs/blueprints/flare/features/lottie-open.md, Screens and
// states): flare-lottie-open-note-{light,dark}, the Flare window after a Lottie open landed with two parts left
// out: the import note above the stage names the precomp and the image, one InspectorNote row each, beside
// Close; flare-lottie-open-long-note-light, twelve parts left out, names three and counts the rest; the bounce is on stage, untitled. The open is landed through `finishLottieOpen` as the window's open
// does, so the image doesn't wait on LO-3's reader. The window bumps FlareWindow.bodyRuns, so the suite nests in
// BodyCountSuites. macOS only.
#if os(macOS)
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct FlareLottieOpenSnapshots {
        static let skipped = [
            "The precomp \"Logo\" isn't supported yet and was left out.",
            "The image \"Photo\" isn't supported yet and was left out.",
        ]

        @Test func longNote() throws {
            var model = FlareWorkspace(services: .fake())
            let many = (1...12).map { "The image \"Photo \($0)\" isn't supported yet and was left out." }
            model.finishLottieOpen(.success((FlareFixtures.bounce, many)))
            #expect(model.importNoteRows.count == FlareWorkspace.importNoteMaxRows + 1, "the note lists every part")
            try snapshot(
                FlareWindow(model: model)
                    .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "flare-lottie-open-long-note-light", scheme: .light)
        }

        @Test func note() throws {
            var model = FlareWorkspace(services: .fake())
            model.finishLottieOpen(.success((FlareFixtures.bounce, Self.skipped)))
            #expect(model.importNoteRows == Self.skipped, "the note doesn't name both skipped parts")
            #expect(model.fileName == nil, "a Lottie opens untitled")
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(
                    FlareWindow(model: model)
                        .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                    name: "flare-lottie-open-note-\(scheme.name)", scheme: scheme)
            }
        }
    }
}
#endif
