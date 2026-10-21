// FlarePenKernelTests.swift (pen-paths FP-1): 200 seeded pen sequences on the built services, each hashed (FNV-1a) from
// today's drafts and commits so FP-5's move onto PenRules draws exactly as before; `penDraft` reads them back, and
// the opened app's corner clicks (a polyline with no path) too.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlarePenKernelTests {
    struct Seeded {  // SplitMix64, so every platform plays the same sequences.
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = (state ^ (state >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return Int((z ^ (z >> 31)) % UInt64(max(bound, 1)))
        }
    }

    static func text(_ p: Point) -> String { "\(p.x),\(p.y)" }

    /// A new document on the built services with `tool` chosen.
    static func workspace(_ tool: FlareTool) -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        workspace.selectTool(tool)
        return workspace
    }

    static func text(_ shape: FlareShape?) -> String {
        guard let shape else { return "-" }
        let elements = (shape.path?.elements ?? []).map { element -> String in
            switch element {
            case .move(let p): "M" + text(p)
            case .line(let p): "L" + text(p)
            case .quad(let c, let p): "Q" + text(c) + " " + text(p)
            case .cubic(let c1, let c2, let p): "C" + text(c1) + " " + text(c2) + " " + text(p)
            case .close: "Z"
            }
        }
        return shape.points.map(text).joined(separator: ";") + "|" + elements.joined(separator: " ") + "|\(shape.closed)"
    }

    static func fnv(_ text: String) -> String {
        var hash: UInt32 = 0x811C_9DC5
        for byte in text.utf8 { hash = (hash ^ UInt32(byte)) &* 0x0100_0193 }
        return String(hash, radix: 16)
    }

    /// One sequence: 3 to 8 clicks or drags on a 10 pt grid, some near the first anchor, at stage scale 0.5, 1 or 2.
    static func play(seed: UInt64) -> String {
        var random = Seeded(state: seed)
        var workspace = workspace(.pen)
        var log: [String] = []
        for _ in 0..<(3 + random.next(6)) {
            let first = workspace.draft?.anchors.first
            var point = Point(x: Double(random.next(30) * 10), y: Double(random.next(30) * 10))
            if let first, random.next(5) == 0 { point = Point(x: first.x + Double(random.next(4)), y: first.y) }
            let end = random.next(3) == 0
                ? Point(x: point.x + Double(random.next(81) - 40), y: point.y + Double(random.next(81) - 40)) : point
            let scale = [0.5, 1, 2][random.next(3)]
            workspace.drag(from: point, to: end, stageScale: scale)
            let committed = workspace.layers.first?.shapes.first
            log.append(text(workspace.draft?.shape) + "#\(workspace.layers.count)#" + text(committed))
        }
        return fnv(log.joined(separator: "\n"))
    }

    static let recorded: [String] = [
        "85074a65", "5ef9ba05", "33fde26f", "186b731e", "f5c0b48b", "4d0f04cf", "c030953d", "d3a622e9", "5c20c8cf", "b5a276b", "46fe8fc8", "163139ab", "cb65ef65", "28d45c25", "5daa83f4", "d46455c5", "52bd592e", "49fd49e5", "e13a5dc7", "25ec0ddb",
        "3bfb4ab2", "6dde5b4a", "6e8c89ba", "403d2d91", "6685f468", "b21dfe04", "ceae4e39", "7dd82b7e", "c6132372", "67adb1a3", "8b20c12e", "d3fad80", "baa732fe", "134bae57", "3286c22a", "1867971b", "1cce523a", "d3ee4b69", "91e7545d", "8a684b3d",
        "e5b0c8c9", "69632838", "8246f9a3", "642608e4", "3a869d88", "ed5c0d31", "ea293529", "25988060", "beb48316", "430f2c1", "ee0e14a2", "c210af84", "58368c60", "c6b2795f", "4bc47189", "2982b623", "97f6faf1", "9b9ab886", "3ea3d385", "f5430745",
        "14d0da3e", "998b3056", "771a8dd1", "ef0aebd2", "892c9064", "e914ff01", "a65b2e1b", "dfa9d16f", "7050ddb8", "5d99daa", "43f4e44f", "144a273", "20dd8e0c", "282f45f2", "53ecfcb8", "495633f5", "1492bf46", "4d328130", "8cb58816", "3f4588df",
        "5cfa18bb", "f59de3a8", "906e24d7", "ecaccde1", "cc7009db", "897845e", "985a7410", "521e4c1f", "7eb7a272", "7c353975", "65b1cd92", "6fe4817e", "8c94ed6", "6c520d58", "4680dfab", "8b0ede76", "1820eda5", "b1aefa7b", "4af53f80", "57918df",
        "9a9999b1", "6d6665da", "c846c06e", "21325b5e", "968533db", "f1ac2111", "74788166", "6c80949d", "a6c30eac", "bad3818f", "7c5594f", "c102e88e", "a2996a10", "9accf946", "494cc806", "587ffa8a", "958f9a31", "36d3ed97", "afdb2751", "a6d5a481",
        "22fbb2a9", "d1c12370", "d5998619", "8b08fb5e", "2106698b", "4a672972", "12b32cb1", "12c6055b", "a20f0b63", "b73a1f91", "da9b5cc3", "3092e13e", "af51599a", "d6d4dbe6", "31c1df69", "6729f519", "ba6ae140", "a9a9627e", "5f750cd6", "48983f4",
        "f91f8d6", "230982ed", "4833d314", "fd11ddbc", "b54f3646", "8da1257", "a2e34343", "a78dc610", "ea48ab3b", "bfd042a6", "e2910301", "2f8f6150", "d7226b4f", "917fc302", "d54c9ed8", "211074ca", "8ba66320", "b03c2994", "f4b9dae6", "1ed88bba",
        "67d5474a", "a7a90103", "95e65793", "fda6957f", "4e4a9bb", "a0d2af96", "80401ff1", "5d9939e", "3b0bb433", "36dceeb4", "f1157916", "a3c325dd", "9293f497", "96b1d436", "b89556c7", "b73c77e7", "71853c96", "94448f8b", "b0f9dd43", "c9f4a9cb",
        "2f04a7c7", "36f452f9", "a3ce6f1d", "dbbdbc1a", "481b1c5f", "78324b56", "665e93d8", "ca0d1b43", "2c29c4b6", "fcc18bd0", "59a9c742", "3375691a", "d4b10c61", "c0d8a1f0", "e51903cc", "b120daa7", "45036d77", "5cb37aef", "6e045906", "b1aefcbe"
    ]

    @Test func seededSequencesDrawAsRecorded() {
        let hashes = (0..<200).map { Self.play(seed: UInt64($0)) }
        #expect(hashes == Self.recorded, "\(hashes)")
    }

    @Test func loneSmoothFirstAnchorKeepsHandle() throws {
        var workspace = Self.workspace(.pen)
        workspace.drag(from: Point(x: 10, y: 10), to: Point(x: 40, y: 10))
        #expect(workspace.draft?.shape.path?.elements == [.move(to: Point(x: 10, y: 10)), .move(to: Point(x: 40, y: 10))])
        let pen = try #require(workspace.penDraft)
        #expect(pen.contour.anchors.count == 1 && pen.contour.anchors.first?.handleOut == Point(x: 40, y: 10))
    }

    @Test func penViewReadsTheDraftAndWritesItBack() throws {
        var workspace = Self.workspace(.pen)
        workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 0, y: 0), stageScale: 2)
        workspace.drag(from: Point(x: 100, y: 0), to: Point(x: 130, y: 20), stageScale: 2)
        workspace.drag(from: Point(x: 100, y: 100), to: Point(x: 100, y: 100), stageScale: 2)
        let before = try #require(workspace.draft)
        let pen = try #require(workspace.penDraft)
        #expect(pen.scale == 2 && !pen.contour.closed)
        #expect(pen.contour.anchors.map(\.point) == before.anchors)
        #expect(pen.contour.anchors.map { $0.handleOut != nil } == [false, true, false])
        workspace.penDraft = pen
        #expect(workspace.draft == before)
        workspace.penDraft = nil
        #expect(workspace.draft == nil && workspace.penDraft == nil)
    }

    /// On a document the app opens (FlareLaunch's services), corner clicks leave the draft's shape a polyline with no path; `penDraft`
    /// still reads its anchors (the stage's path overlay outlined nothing until it did) and writes the same draft back.
    @Test func cornerClicksReadAsAnchors() throws {
        var workspace = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        workspace.selectTool(.pen)
        workspace.drag(from: Point(x: 300, y: 60), to: Point(x: 300, y: 60))
        workspace.drag(from: Point(x: 460, y: 180), to: Point(x: 460, y: 180))
        let before = try #require(workspace.draft)
        let pen = try #require(workspace.penDraft)
        #expect(pen.contour.anchors.map(\.point) == [Point(x: 300, y: 60), Point(x: 460, y: 180)] && !pen.contour.closed)
        workspace.penDraft = pen
        #expect(workspace.draft == before)
    }

    @Test func noPenDraftOutsideThePen() {
        var workspace = Self.workspace(.rectangle)
        workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 40, y: 40))
        #expect(workspace.draft != nil && workspace.penDraft == nil)
    }

    @Test func addPathCommitsOneAddPathStep() throws {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        let path = VectorPath(polyline: [Point(x: 0, y: 0), Point(x: 50, y: 0), Point(x: 50, y: 50)], closed: true)
        let id = try workspace.addPath(path, name: "Add Path")
        #expect(workspace.layers.first?.id == id && workspace.undoActionName == "Undo Add Path")
        #expect(workspace.layers.first?.shapes.first?.path == path)
        #expect(throws: (any Error).self) { try workspace.addPath(VectorPath(), name: "Add Path") }
    }
}
