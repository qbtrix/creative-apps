// DesignWindowEditedDotTests.swift: the real Design window's edited dot (#6199). DesignWindow, hosted off screen
// on `cards` saved to a temp file, starts with NSWindow.isDocumentEdited off; one document edit through the
// window's own perform (`.setFrame`) turns it on, and File > Save (`.save`, written to that file) turns it off.
// The window's `suite.window.edited` element (SuiteUI's DocumentEditedView), which the journeys read, says the
// same each time. Nested in BodyCountSuites, which runs serialized, because DesignWindow.lastPerform and
// lastWorkspace are process-wide. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import Foundation
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignWindowEditedDotTests {
        @Test(.timeLimit(.minutes(1))) func anEditSetsTheDotAndSaveClearsIt() async throws {
            #if DEBUG
            let folder = FileManager.default.temporaryDirectory.appending(path: "design-dot-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let file = folder.appending(path: "cards.design")
            var seed = DesignWorkspace()
            seed.useServices(.fake)
            let opened = seed.openFixture("cards")
            #expect(opened)
            seed.didSave(to: file)  // so File > Save writes here, with no panel
            DesignWindow.lastPerform = nil
            DesignWindow.lastWorkspace = nil
            let w = RenderBudgetWindow(DesignWindow(seed: seed))
            defer { w.close() }
            try await w.settle(500)
            let perform = try #require(DesignWindow.lastPerform, "the window never started")

            #expect(await settles { !w.window.isDocumentEdited }, "the saved file opened with the dot on")
            #expect(await settles { w.label("suite.window.edited") == "saved" },
                    "suite.window.edited read \(w.label("suite.window.edited") ?? "nothing") on open")

            perform(.setFrame("node-2", x: 300, y: 300, width: 96, height: 96))
            #expect(DesignWindow.lastWorkspace?.isDirty == true, "the edit never reached the document")
            #expect(await settles { w.window.isDocumentEdited }, "an edit in the real window left the dot off")
            #expect(await settles { w.label("suite.window.edited") == "edited" },
                    "suite.window.edited read \(w.label("suite.window.edited") ?? "nothing") after an edit")

            perform(.save)
            #expect(DesignWindow.lastWorkspace?.isDirty == false, "File > Save left the document dirty")
            #expect(FileManager.default.fileExists(atPath: file.path), "File > Save wrote no file")
            #expect(await settles { !w.window.isDocumentEdited }, "a save in the real window left the dot on")
            #expect(await settles { w.label("suite.window.edited") == "saved" },
                    "suite.window.edited read \(w.label("suite.window.edited") ?? "nothing") after a save")
            #endif
        }

        /// Lets the main actor run until `condition` holds, at most two seconds.
        private func settles(_ condition: () -> Bool) async -> Bool {
            let deadline = Date().addingTimeInterval(2)
            while !condition() {
                if Date() > deadline { return false }
                try? await Task.sleep(for: .milliseconds(10))
            }
            return true
        }
    }
}
#endif
