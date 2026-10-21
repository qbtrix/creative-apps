// DesignKernelTransformAdapterTests.swift: Design's box transform runs on
// SuiteKernel (adopt-kernel-transform AT-d1). Each DesignHandle is the
// EditorHandle of the same name and the kernel's inside and rotate are no
// Design handle; Shift and Option reach the kernel as EditModifiers; a resize
// is BoxMath.resized, the handles BoxMath.handles' centres, a press
// HandleHit.handle at the workspace's handleTolerance, and a box of several
// layers scales each one by BoxMath.scaled, never below 1 pt (AT-d2). The app's own tests pin the
// behaviour; these pin the forwarding.
// Plan: Tests/mutations/DesignModel.KernelTransformAdapter.json. Runs on Linux
// and macOS.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignKernelTransformAdapterTests {
    static let pairs: [(DesignHandle, EditorHandle)] = [
        (.topLeft, .topLeft), (.top, .top), (.topRight, .topRight), (.right, .right),
        (.bottomRight, .bottomRight), (.bottom, .bottom), (.bottomLeft, .bottomLeft), (.left, .left),
    ]

    /// `rect`'s edges as the kernel's Rect, built here so a test never trusts the adapter's own.
    static func edges(_ rect: DesignRect) -> Rect {
        Rect(minX: rect.x, minY: rect.y, maxX: rect.x + rect.width, maxY: rect.y + rect.height)
    }

    @Test func eachDesignHandleIsTheEditorHandleOfItsName() {
        #expect(Self.pairs.count == DesignHandle.allCases.count)
        for (design, editor) in Self.pairs {
            #expect(design.editorHandle == editor)
            #expect(DesignHandle(editor) == design)
            #expect(design.isCorner == editor.isCorner)
        }
        #expect(DesignHandle(.inside) == nil)
        #expect(DesignHandle(.rotate) == nil)
    }

    @Test func shiftAndOptionReachTheKernelAndNoSnapDoesNot() {
        #expect(DesignModifiers().editModifiers == [])
        #expect(DesignModifiers.shift.editModifiers == .shift)
        #expect(DesignModifiers.option.editModifiers == .option)
        #expect(DesignModifiers([.shift, .option]).editModifiers == [.shift, .option])
        #expect(DesignModifiers.noSnap.editModifiers == [])
    }

    @Test func aResizeIsTheKernelsForEveryHandleAndModifier() {
        let rect = rc(40, 40, 160, 120)
        let flags: [(Bool, Bool, EditModifiers)] = [
            (false, false, []), (true, false, .shift), (false, true, .option), (true, true, [.shift, .option]),
        ]
        for (design, editor) in Self.pairs {
            for delta in [pt(20, 10), pt(-30, 50), pt(-500, -400)] {
                for (keepAspect, fromCenter, modifiers) in flags {
                    let got = rect.resized(design, by: delta, keepAspect: keepAspect, fromCenter: fromCenter)
                    let want = BoxMath.resized(Self.edges(rect), editor, by: Point(x: delta.x, y: delta.y), modifiers: modifiers)
                    #expect(Self.edges(got) == want, "\(design) \(delta) shift \(keepAspect) option \(fromCenter)")
                }
            }
        }
    }

    @Test func theHandlesSitAtTheKernelsCentres() {
        let rect = rc(40, 40, 160, 120)
        let shown = rect.handles(size: 6)
        let squares = BoxMath.handles(of: Self.edges(rect), size: 6)
        #expect(shown.count == 8)
        for (design, editor) in Self.pairs {
            let square = squares[editor]
            #expect(shown[design] == square.map { pt(($0.minX + $0.maxX) / 2, ($0.minY + $0.maxY) / 2) })
        }
    }

    @Test func aPressFindsTheKernelsHandleAtTheWorkspaceTolerance() throws {
        var workspace = openDesign()
        try workspace.addNode(.rectangle, frame: rc(40, 40, 160, 120), in: "node-1")
        let rect = Self.edges(rc(40, 40, 160, 120))
        for tolerance in [2.0, 10.0] {
            workspace.setHandleTolerance(tolerance)
            for x in stride(from: 26.0, through: 214, by: 4) {
                for y in stride(from: 26.0, through: 174, by: 4) {
                    let want = HandleHit.handle(at: Point(x: x, y: y), in: rect, tolerance: tolerance).flatMap(DesignHandle.init)
                    #expect(workspace.handle(at: pt(x, y)) == want, "\(x), \(y) at \(tolerance)")
                }
            }
        }
    }

    @Test func severalLayersScaleByTheKernel() throws {
        let page = DesignMarqueeTests.cards()
        let ids = ["A", "B"]
        let frames = ids.compactMap { page.nodes.node($0)?.frame }
        let box = try #require(DesignRect.union(frames))
        let edit = try LiveTransforming().resize(ids, handle: .bottomRight, by: pt(40, 30), modifiers: [], on: page)
        let new = box.resized(.bottomRight, by: pt(40, 30), keepAspect: false, fromCenter: false)
        for (id, frame) in zip(ids, frames) {
            let want = BoxMath.scaled(Self.edges(frame), from: Self.edges(box), to: Self.edges(new))
            let got = try #require(edit.nodes.node(id)?.frame)
            #expect(abs(got.x - want.minX) < 1e-9 && abs(got.y - want.minY) < 1e-9)
            #expect(abs(got.width - want.width) < 1e-9 && abs(got.height - want.height) < 1e-9)
        }
    }

    @Test func aLayerScaledDownStaysAtLeastOnePoint() throws {
        let page = DesignMarqueeTests.cards()
        let edit = try LiveTransforming().resize(["A", "B"], handle: .left, by: pt(10_000, 0), modifiers: [], on: page)
        for id in ["A", "B"] {
            let got = try #require(edit.nodes.node(id)?.frame)
            #expect(got.width >= 1 && got.height >= 1, "\(id): \(got)")
        }
    }
}
