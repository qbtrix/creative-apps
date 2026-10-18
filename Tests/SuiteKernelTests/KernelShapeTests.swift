// KernelShapeTests.swift: the kernel's shape (editor-kernel EK-1, slice EK-a).
// The geometry aliases are FlareCore's types, `EditorHandle` has its ten
// cases with the four corners marked, and nothing under Sources/SuiteKernel
// imports an app Model, SuiteUI, SuiteModel or a Darwin-only framework, so the
// kernel stays Linux-safe and below every app. KJ0, the kernel shape walk,
// is here disabled by name: EK-2 and EK-3 extend it with each module's stubs
// and EK-3 turns it on (docs/factory/lead.md rule 13).
import Foundation
import Testing
import SuiteKernel

@Suite struct KernelShapeTests {
    /// The kernel folder, found from this file: Tests/SuiteKernelTests/ -> Sources/SuiteKernel/.
    static let kernelSources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources").appendingPathComponent("SuiteKernel")

    @Test func geometryAliasesAndHandles() {
        // The aliases are FlareCore's types, not copies: a kernel Point is FlareCore.Point.
        #expect(String(reflecting: SuiteKernel.Point.self) == "FlareCore.Point")
        #expect(String(reflecting: SuiteKernel.Rect.self) == "FlareCore.Rect")
        #expect(String(reflecting: SuiteKernel.Matrix.self) == "FlareCore.Matrix")
        let origin = Point(x: 1, y: 2)
        #expect(origin.x == 1 && origin.y == 2)
        let box = Rect(minX: 0, minY: 0, maxX: 10, maxY: 5)
        #expect(box.width == 10 && box.height == 5)
        #expect(Matrix.identity.apply(origin) == origin)

        #expect(EditorHandle.allCases.count == 10)
        #expect(EditorHandle.allCases.first == .topLeft)
        #expect(EditorHandle.allCases.last == .rotate)
        let corners = EditorHandle.allCases.filter(\.isCorner)
        #expect(corners == [.topLeft, .topRight, .bottomRight, .bottomLeft])
        #expect(EditorHandle.topLeft.isCorner)
        #expect(!EditorHandle.top.isCorner && !EditorHandle.inside.isCorner && !EditorHandle.rotate.isCorner)

        // The enums the modules share exist with the packet's cases.
        let picks: [Pick] = [.replace, .toggle, .extend]
        #expect(picks.count == 3)
        let directions: [Direction] = [.up, .down, .left, .right]
        #expect(directions.count == 4)
        let both: EditModifiers = [.shift, .option]
        #expect(both.contains(.shift) && both.contains(.option) && !both.contains(.command))
        #expect(EditModifiers.shift.rawValue != EditModifiers.option.rawValue)
        #expect(EditModifiers.option.rawValue != EditModifiers.command.rawValue)
        #expect(EditModifiers().isEmpty)
        #expect(KernelShape.version >= 1)
    }

    @Test func importsOnlyFoundationAndFlareCore() throws {
        let files = try Self.swiftFiles(under: Self.kernelSources)
        #expect(files.contains { $0.hasSuffix("Geometry.swift") })
        #expect(files.contains { $0.hasSuffix("SuiteKernel.swift") })
        let forbidden = try Regex(
            #"^\s*(@testable\s+)?import\s+(DesignModel|PhotoModel|FlareModel|HaloModel|LibraryModel|SuiteUI|SuiteModel|SwiftUI|AppKit|UIKit|Combine|CoreGraphics|QuartzCore)\b"#)
        for file in files {
            let text = try String(contentsOf: Self.kernelSources.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(separator: "\n") where line.contains(forbidden) {
                Issue.record("Sources/SuiteKernel/\(file) imports what the kernel must not: \(line)")
            }
        }
    }

    /// EK-2: history, selection and the tree are declared, their stubs answer
    /// without trapping, and the fixtures have the packet's shape.
    @Test func stubsReturnFakes() throws {
        var history = History<Int>()
        #expect(!history.undo { $0 } && !history.redo { $0 })
        history.jump(to: 0) { $0 }
        let reading: any HistoryReading = history
        #expect(!reading.isDirty && !reading.canUndo && !reading.canRedo && reading.undoName == nil)
        #expect(history.steps.isEmpty && history.index == 0 && history.currentStepID == history.savedStepID)
        // EK-8 built the body: a recorded step is now undoable (HistoryTests covers the rest).
        history.record("Move", 1, key: "drag")
        history.endRun()
        #expect(history.steps == ["Move"] && history.canUndo && history.isDirty)

        var selection = Selection(["a", "b"])
        #expect(selection.primary == "b" && selection.set == ["a", "b"] && selection.contains("a"))
        // EK-10 built the body: with no anchor, extend appends (SelectionTests covers the rest).
        let picked = selection.pick("c", .extend, order: ["a", "b", "c"])
        #expect(picked && selection.ordered == ["a", "b", "c"] && selection.primary == "c")
        selection.move(.right, order: ["a", "b", "c"], columns: 3)
        #expect(selection.ordered == ["c"])
        selection.prune { $0 != "c" }
        #expect(selection.ordered.isEmpty && selection.primary == nil)

        var tree = KernelFixtures.tree200
        #expect(tree.rows(expanded: []).count == 7)
        let groups = ["header", "hero", "cards", "gallery", "archive", "footer"]
            + (1...4).flatMap { r in ["row-\(r)"] + (1...3).map { "row-\(r)-col-\($0)" } }
        let all = tree.rows(expanded: Set(groups))
        #expect(all.count == 200 && all.map(\.depth).max() == 3)
        #expect(all.first?.id == "background" && all.contains { $0.id == "card-7" && $0.name == "Card 7" })
        #expect(all.filter(\.isHidden).map(\.id) == ["archive"] && all.filter(\.isLocked).map(\.id) == ["footer"])
        #expect(all.first { $0.id == "archive-1" }?.inheritsHidden == true)
        try tree.move("card-7", into: "header", at: 3)
        try tree.arrange(.bringToFront, ["hero"])
        #expect(try tree.group(["hero"], name: "G", payload: KernelFixtures.cards.roots[0].payload) { "g1" } == "g1")
        try tree.ungroup("g1")
        // The tree has its body (EK-12): the edits land and the cascades read ancestors.
        #expect(tree.node("header")?.children.count == 4 && tree.roots.last?.id == "hero" && tree.ancestors(of: "hero") == [])
        let updated = tree.update("hero") { node in node.name = "X" }
        #expect(tree.duplicate(["nowhere"]) { "copy" }.isEmpty && updated)
        #expect(tree.frontToBack.count == 200 && tree.isEffectivelyHidden("archive-1"))
        #expect(tree.worldPlacement(of: "hero") { _ in .identity } == .identity)

        let desktop = KernelFixtures.cards.rows(expanded: ["desktop"])
        #expect(desktop.map(\.name) == ["Desktop", "Hidden", "Locked", "Pair", "Title", "C", "B", "A"])
        #expect(KernelFixtures.cards.roots.first?.payload.frame.width == 1440)
    }

    /// KJ0, the kernel shape walk: every module's declared shape in one pass.
    /// EK-1 walks the geometry; EK-2 adds history, selection and the tree,
    /// EK-3 keys, transform, export and session, and turns it on.
    @Test(.disabled("waits on EK-3")) func kernelShapeWalk() {
        let box = Rect(minX: 10, minY: 20, maxX: 110, maxY: 70)
        let handles = EditorHandle.allCases
        #expect(handles.filter(\.isCorner).count == 4)
        #expect(handles.filter { !$0.isCorner }.count == 6)
        var modifiers = EditModifiers()
        modifiers.insert(.shift)
        #expect(modifiers == .shift)
        let moved = Matrix.identity.apply(Point(x: box.minX, y: box.minY))
        #expect(moved.x == 10 && moved.y == 20)
    }

    /// Every .swift file under `root`, as paths relative to it, folders included, sorted.
    static func swiftFiles(under root: URL) throws -> [String] {
        try FileManager.default.subpathsOfDirectory(atPath: root.path).filter { $0.hasSuffix(".swift") }.sorted()
    }
}
