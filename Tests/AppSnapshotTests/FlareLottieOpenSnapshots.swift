// FlareLottieOpenSnapshots.swift (lottie-open LO-4; docs/blueprints/flare/features/lottie-open.md, Screens and
// states): flare-lottie-open-note-{light,dark}, the Flare window after a Lottie open landed with two parts left
// out: the import note above the stage names the precomp and the image, one InspectorNote row each, beside
// Dismiss; the bounce is on stage, untitled. The open is landed through `finishLottieOpen` as the window's open
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
