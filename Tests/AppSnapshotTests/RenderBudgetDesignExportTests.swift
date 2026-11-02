// RenderBudgetDesignExportTests.swift: the export sheet's render budget
// (design-export; docs/blueprints/design/features/design-export.md, Quality
// tests) on the real window through the harness (RenderBudgetHarness.swift).
// `sheet`: on `cards` with Desktop selected and the fakes, it opens File >
// Export… (through DesignWindow's DEBUG `openExport` hook: the hosted window has
// no menu bar), picks a format, a scale and a scope chip 3 times each, then
// presses Cancel (`design.export.cancel`). The sheet's run is the export area's
// own state, so the window body runs only for the request: at most 2 bodies over
// the whole walk. `liveRun` (DE-10): on the live services, Desktop, A and B
// selected, Scope Selection at PNG 1x into a temp folder (DesignExportArea's
// DEBUG `testFolder`, standing in for the folder panel), Export writes three
// files: at most 4 DesignEditor bodies (one per progress step plus the finish;
// the run is the area's state, the canvas never redraws). The
// sheet is its own window attached to the hosted one, so its controls are found
// from `attachedSheet`'s accessibility tree. The proofs on the live services:
// a read-only folder fails on Desktop.png with the system's reason and closes on Done, the JPEG
// chip writes a 2x JPEG on white, a refused plan (Selection, nothing selected)
// leaves Export off and starts nothing, and a finished run's options reach the
// Model's export defaults. Nested in BodyCountSuites, as every
// suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignExportTests {
        @Test(.timeLimit(.minutes(2)))
        func sheet() async throws {
            var model = DesignFixtures.cards
            model.useServices(.fake)
            model.selectItem("node-1")
            let w = RenderBudgetWindow(DesignWindow(seed: model))
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return DesignWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let chips = [
                "design.export.format.svg", "design.export.format.pdf", "design.export.format.png",
                "design.export.scale.2x", "design.export.scale.3x", "design.export.scale.1x",
                "design.export.scope.page", "design.export.scope.selection", "design.export.scope.frame",
            ]
            var missing: [String] = []
            let walk = try await w.measure("design export sheet: open, 9 picks, cancel", bodies: bodies) {
                try await w.ticks(1) { _ in
                    #if DEBUG
                    DesignWindow.openExport?()
                    #endif
                }
                guard let sheet = await Self.sheet(of: w.window) else { return missing = ["the sheet"] }
                try await w.ticks(chips.count) { i in
                    if let chip = chips.dropFirst(i - 1).first, !Self.press(chip, in: sheet) { missing.append(chip) }
                }
                try await w.ticks(1) { _ in if !Self.press("design.export.cancel", in: sheet) { missing.append("Cancel") } }
            }
            #expect(missing.isEmpty, "nothing to press for \(missing): \(walk)")
            #expect(w.window.attachedSheet == nil, "Cancel left the sheet open")
            // The request is one window body; the sheet's edits are the area's own. Target: 1.
            expectBodies(walk, atMost: 2, target: 1)
        }

        @Test(.timeLimit(.minutes(2)))
        func liveRun() async throws {
            var model = DesignFixtures.cards
            for id in ["node-1", "node-2", "node-3"] { model.toggleSelection(id) }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("design-live-run-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            #if DEBUG
            DesignExportArea.testFolder = folder
            defer { DesignExportArea.testFolder = nil }
            #endif
            let w = RenderBudgetWindow(DesignWindow(seed: model))
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return DesignEditor.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            #if DEBUG
            DesignWindow.openExport?()
            #endif
            guard let sheet = await Self.sheet(of: w.window) else { return #expect(Bool(false), "no export sheet") }
            #expect(Self.press("design.export.scope.selection", in: sheet), "no Selection chip")
            try await w.settle(200)
            let listing = { (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.sorted() ?? [] }
            let run = try await w.measure("design export live run: 3 PNG files", bodies: bodies) {
                #expect(Self.press("design.export.start", in: sheet), "no Export button")
                for _ in 0..<200 where listing().count < 3 { try await Task.sleep(for: .milliseconds(20)) }
                try await w.settle(200)
            }
            #expect(listing() == ["A.png", "B.png", "Desktop.png"], "the folder holds \(listing())")
            // One body per progress step plus the finish; the target is the finish alone.
            expectBodies(run, atMost: 4, target: 1)
            _ = Self.press("design.export.dismiss", in: sheet)
        }

        /// A temp folder, removed by the caller, set as DesignExportArea's DEBUG `testFolder`.
        static func folder(_ name: String) throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("design-\(name)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            #if DEBUG
            DesignExportArea.testFolder = folder
            #endif
            return folder
        }

        /// The real window on `model`'s live services with File > Export… open, and its sheet.
        static func openSheet(_ model: DesignWorkspace) async throws -> (RenderBudgetWindow<DesignWindow>, NSWindow?) {
            let w = RenderBudgetWindow(DesignWindow(seed: model))
            try await w.settle(200)
            #if DEBUG
            DesignWindow.openExport?()
            #endif
            return (w, await Self.sheet(of: w.window))
        }

        /// Waits up to four seconds for a text in `window`'s accessibility tree to contain `text`.
        static func waitFor(_ text: String, in window: NSWindow) async -> Bool {
            for _ in 0..<200 {
                if texts(in: window).contains(where: { $0.contains(text) }) { return true }
                try? await Task.sleep(for: .milliseconds(20))
            }
            return false
        }

        /// Every label and string value under `element`.
        static func texts(in element: Any, depth: Int = 0) -> [String] {
            let node = element as AnyObject
            let label: String?? = node.accessibilityLabel?()
            let value: Any?? = node.accessibilityValue?()
            let own = [label ?? nil, (value ?? nil) as? String].compactMap { $0 }
            guard depth < 60 else { return own }
            return own + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { texts(in: $0, depth: depth + 1) }
        }

        /// DE-11 (J18's bug): a folder Design can't write to fails the run on the first file, the line naming it
        /// and carrying the system's own reason, and nothing is written.
        @Test(.timeLimit(.minutes(2)))
        func readOnlyFolderFailsWithTheSystemsReason() async throws {
            var model = DesignFixtures.cards
            model.selectItem("node-1")
            let folder = try Self.folder("read-only")
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
                try? FileManager.default.removeItem(at: folder)
                #if DEBUG
                DesignExportArea.testFolder = nil
                #endif
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
            let (w, sheet) = try await Self.openSheet(model)
            defer { w.close() }
            guard let sheet else { return #expect(Bool(false), "no export sheet") }
            #expect(Self.press("design.export.start", in: sheet), "no Export button")
            let failed = await Self.waitFor("Desktop.png couldn't be written.", in: sheet)
            #expect(failed, "no failed line: \(Self.texts(in: sheet))")
            #expect(Self.texts(in: sheet).contains { $0.contains("Desktop.png couldn't be written. You don’t have permission") },
                    "the line lacks the system's reason: \(Self.texts(in: sheet))")
            #expect(((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? ["?"]).isEmpty)
            // J18 closes the failed sheet: the line shows, so the close button is Done, not Cancel.
            #expect(Self.node("design.export.cancel", in: sheet) == nil, "the failed sheet still offers Cancel")
            #expect(Self.press("design.export.dismiss", in: sheet), "the failed sheet has no Done")
            for _ in 0..<100 where w.window.attachedSheet != nil { try await Task.sleep(for: .milliseconds(20)) }
            #expect(w.window.attachedSheet == nil, "Done left the failed sheet open")
        }

        /// The JPEG chip writes a JPEG: Desktop at 2x decodes at 2880 × 2048 on its frame's fill, not black.
        @Test(.timeLimit(.minutes(2)))
        func jpegLiveRunWritesAJPEG() async throws {
            let folder = try Self.folder("jpeg")
            defer {
                try? FileManager.default.removeItem(at: folder)
                #if DEBUG
                DesignExportArea.testFolder = nil
                #endif
            }
            let (w, sheet) = try await Self.openSheet(DesignFixtures.cards)
            defer { w.close() }
            guard let sheet else { return #expect(Bool(false), "no export sheet") }
            #expect(Self.press("design.export.format.jpeg", in: sheet), "no JPEG chip")
            try await w.settle(100)
            #expect(Self.press("design.export.scale.2x", in: sheet), "no 2x chip")
            try await w.settle(100)
            #expect(Self.press("design.export.start", in: sheet), "no Export button")
            let done = await Self.waitFor("Exported 1 file", in: sheet)
            #expect(done, "no finished line: \(Self.texts(in: sheet))")
            let file = folder.appendingPathComponent("Desktop.jpg")
            let image = try #require(RGBAImage(png: try Data(contentsOf: file)), "Desktop.jpg doesn't decode")
            #expect(image.width == 2880 && image.height == 2048, "Desktop.jpg is \(image.width) × \(image.height)")
            // Desktop's own fill (DesignColor.shape, 217 gray), as the canvas paints it; a PNG under a .jpg name read black.
            #expect(image.bytes.prefix(3).allSatisfy { abs(Int($0) - 217) <= 4 }, "the top-left reads \(Array(image.bytes.prefix(4)))")
            _ = Self.press("design.export.dismiss", in: sheet)
        }

        /// A refused plan disables Export, saying why: Scope Selection with nothing selected starts no run.
        @Test(.timeLimit(.minutes(2)))
        func refusedPlanDisablesExport() async throws {
            let folder = try Self.folder("refused")
            defer {
                try? FileManager.default.removeItem(at: folder)
                #if DEBUG
                DesignExportArea.testFolder = nil
                #endif
            }
            let (w, sheet) = try await Self.openSheet(DesignFixtures.cards)
            defer { w.close() }
            guard let sheet else { return #expect(Bool(false), "no export sheet") }
            #expect(Self.press("design.export.scope.selection", in: sheet), "no Selection chip")
            try await w.settle(200)
            let start = try #require(Self.node("design.export.start", in: sheet))
            #expect((start.isAccessibilityEnabled?() ?? true) == false, "Export is enabled on a refused plan")
            _ = Self.press("design.export.start", in: sheet)
            try await w.settle(200)
            #expect(!Self.texts(in: sheet).contains { $0.contains("couldn't") || $0.contains("Exported") }, "a run started")
            #expect(((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? ["?"]).isEmpty)
            #expect(Self.press("design.export.scope.frame", in: sheet), "no Frame chip")
            try await w.settle(200)
            #expect((Self.node("design.export.start", in: sheet)?.isAccessibilityEnabled?() ?? false) == true, "Frame left Export off")
            _ = Self.press("design.export.cancel", in: sheet)
        }

        /// A finished run's options reach the Model, so the next sheet (and the window's catalog) open with them.
        @Test(.timeLimit(.minutes(2)))
        func aFinishedRunIsRemembered() async throws {
            var model = DesignFixtures.cards
            model.selectItem("node-2")
            let folder = try Self.folder("remember")
            defer {
                try? FileManager.default.removeItem(at: folder)
                #if DEBUG
                DesignExportArea.testFolder = nil
                #endif
            }
            let (w, sheet) = try await Self.openSheet(model)
            defer { w.close() }
            guard let sheet else { return #expect(Bool(false), "no export sheet") }
            #expect(Self.press("design.export.format.svg", in: sheet), "no SVG chip")
            try await w.settle(200)
            #expect(Self.press("design.export.scope.selection", in: sheet), "no Selection chip")
            try await w.settle(200)
            #expect(Self.press("design.export.start", in: sheet), "no Export button")
            #expect(await Self.waitFor("Exported 1 file", in: sheet), "no finished line: \(Self.texts(in: sheet))")
            _ = Self.press("design.export.dismiss", in: sheet)
            try await w.settle(200)
            #if DEBUG
            let remembered = DesignWindow.lastWorkspace?.exportDefaults
            #expect(remembered?.format == .svg && remembered?.scope == .selection, "the Model remembers \(String(describing: remembered))")
            #endif
        }

        /// The sheet attached to `window`, waiting up to two seconds for SwiftUI to present it.
        static func sheet(of window: NSWindow) async -> NSWindow? {
            for _ in 0..<100 {
                if let sheet = window.attachedSheet { return sheet }
                try? await Task.sleep(for: .milliseconds(20))
            }
            return nil
        }

        /// Presses the element called `identifier` in `window`'s accessibility tree; false when there is none.
        static func press(_ identifier: String, in window: NSWindow) -> Bool {
            node(identifier, in: window)?.accessibilityPerformPress?() ?? false
        }

        /// The first node called `identifier` under `element`, in tree order.
        static func node(_ identifier: String, in element: Any, depth: Int = 0) -> AnyObject? {
            let node = element as AnyObject
            if (node.accessibilityIdentifier?() ?? nil) == identifier { return node }
            guard depth < 60 else { return nil }
            return ((node.accessibilityChildren?() ?? nil) ?? []).lazy
                .compactMap { Self.node(identifier, in: $0, depth: depth + 1) }.first
        }
    }
}
#endif
