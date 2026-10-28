// RenderBudgetLibraryFolderKeysTests.swift: FOLDERS by keyboard alone on the real Library window at 10,000
// photos in their month folders (`large-folders`), the folders packet's keyboard parity row and its key-step
// budget (docs/render-contract.md rule 3). Focus in the sidebar, the down arrow walks from the selected
// collection to the folder root, the right arrow opens it, the down arrow walks into its months (each step
// shows that folder in the grid) and the left arrow closes it again; library-folder-key-{open,month,closed}.png
// record those steps. Each arrow is a key down and up sent straight to the key-capable window and timed with
// the layout and display it forces; folderKeyStepsWithinBudget gates p95 at 16 ms release (8 ms target), 50 ms
// debug, and runs only with LIBRARY_FOLDERS_PERF=1 until Tests/perf-suites.txt lists it. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryFolderKeysTests {
        static let (down, left, right) = ((UInt16(125), "\u{F701}"), (UInt16(123), "\u{F702}"), (UInt16(124), "\u{F703}"))

        @Test(.timeLimit(.minutes(2))) func walkFoldersByKeyboard() async throws {
            _ = try await Self.walk()
        }

        @Test(
            .disabled(
                if: ProcessInfo.processInfo.environment["LIBRARY_FOLDERS_PERF"] != "1",
                "waits on its Tests/perf-suites.txt line"),
            .timeLimit(.minutes(2)))
        func folderKeyStepsWithinBudget() async throws {
            let sorted = try await Self.walk().sorted()
            let p95 = SuiteFrameProbe.nearestRank(sorted, 0.95) ?? 0
            print("RENDER-BUDGET library folder keys-10000: steps \(sorted.count) | p50 \(SuiteFrameProbe.nearestRank(sorted, 0.5) ?? 0) ms | p95 \(p95) ms | max \(sorted.last ?? 0) ms")
            #if DEBUG
            let limit = 50.0
            #else
            let limit = 16.0
            #endif
            #expect(p95 <= limit, "a folder arrow step at 10,000 photos took p95 \(p95) ms (budget \(limit), target 8)")
        }

        /// Walks FOLDERS by arrow keys, checking each step; returns each press's milliseconds.
        static func walk() async throws -> [Double] {
            let w = RenderBudgetWindow(
                LibraryWindow(arguments: ["Library", "-LibraryFixture", "large-folders"]), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            try await w.settle(800)
            let outline = try #require(await w.first(NSOutlineView.self), "no sidebar outline")
            w.window.makeFirstResponder(outline)
            try await w.settle()
            let folderRow = { (row: Int) -> Bool in
                row >= 0 && outline.level(forRow: row) > 0 && outline.isExpandable(outline.item(atRow: row))
            }
            let start = outline.selectedRow
            // Down until the selection sits on the folder root, the one expandable row below level 0.
            var steps: [Double] = []
            let press = { (key: (UInt16, String)) async throws in
                let clock = ContinuousClock(), began = clock.now
                Self.press(key.1, keyCode: key.0, in: w.window)
                w.host.layoutSubtreeIfNeeded()
                w.window.displayIfNeeded()
                steps.append(Double((clock.now - began) / .microseconds(1)) / 1000)
                try await w.settle(60)
            }
            for _ in 0..<20 where !folderRow(outline.selectedRow) { try await press(Self.down) }
            let root = outline.selectedRow
            try #require(folderRow(root), "the down arrow never reached the folder root (from row \(start))")
            #expect(root > start, "the down arrow didn't move the selection")
            let shut = outline.numberOfRows
            try await press(Self.right)
            #expect(outline.numberOfRows > shut, "the right arrow didn't open the folder root")
            #expect(outline.isItemExpanded(outline.item(atRow: root)))
            try Self.capture(w.host, "library-folder-key-open")
            let cells = { w.identifiers().filter { $0.hasPrefix("library.grid.cell.") } }
            let all = Set(cells())
            try await press(Self.down)
            #expect(outline.selectedRow == root + 1, "the down arrow didn't step into the first month")
            let month = Set(cells())
            #expect(month != all, "the first month's grid shows the same cells as its root")
            try await press(Self.down)
            #expect(outline.selectedRow == root + 2, "the down arrow didn't step to the second month")
            #expect(Set(cells()) != month, "the second month's grid shows the first month's cells")
            try Self.capture(w.host, "library-folder-key-month")
            for _ in 0..<8 { try await press(Self.down) }
            for _ in 0..<10 { try await press((126, "\u{F700}")) }
            #expect(outline.selectedRow == root, "the up arrow didn't walk back to the folder root")
            try await press(Self.left)
            #expect(outline.numberOfRows == shut, "the left arrow didn't close the folder root")
            try Self.capture(w.host, "library-folder-key-closed")
            return steps
        }

        /// The window as it stands after a step, in `.build/snapshots/<name>.png`, outside the timed press.
        static func capture(_ view: NSView, _ name: String) throws {
            guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                throw SnapshotError.render(name)
            }
            view.cacheDisplay(in: view.bounds, to: image)
            guard let png = image.representation(using: .png, properties: [:]) else { throw SnapshotError.encode(name) }
            let folder = try packageRoot().appending(path: ".build/snapshots")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appending(path: "\(name).png"))
        }

        /// A key down and up for `characters`, sent straight to `window`.
        static func press(_ characters: String, keyCode: UInt16, in window: NSWindow) {
            for kind in [NSEvent.EventType.keyDown, .keyUp] {
                guard let event = NSEvent.keyEvent(
                    with: kind, location: .zero, modifierFlags: [.numericPad, .function],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                    characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)
                else { Issue.record("no \(kind) event"); return }
                window.sendEvent(event)
            }
        }
    }
}
#endif
