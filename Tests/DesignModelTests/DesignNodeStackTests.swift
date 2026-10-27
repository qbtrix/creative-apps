// DesignNodeStackTests.swift: a deep Design tree must fit a secondary thread's 512 KB stack. Projecting a page
// into the kernel's layer tree (`layerNode`) recurses once per level and holds several copies of the node in each
// frame, so every inline byte of DesignNode costs stack at every level (a 416-byte node crashed DesignModelTests with
// SIGBUS at 61 levels). The rarely set payloads live behind one copy-on-write box; this pins the inline size, walks
// a 64-deep chain on a 512 KB thread, and checks a copy still behaves as a value. Foundation for Thread (Linux too).
import Foundation
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignNodeStackTests {
    static var sizes: String {
        "DesignNode \(MemoryLayout<DesignNode>.size), Fill? \(MemoryLayout<Fill?>.size), "
            + "ShapeSpec? \(MemoryLayout<ShapeSpec?>.size), DesignTextStyle \(MemoryLayout<DesignTextStyle>.size)\n"
    }

    /// Runs `body` on a thread with a `kilobytes` KB stack and waits for it.
    static func onSmallStack(_ kilobytes: Int, _ body: @escaping @Sendable () -> Void) {
        let done = DispatchSemaphore(value: 0)
        let thread = Thread { body(); done.signal() }
        thread.stackSize = kilobytes * 1024
        thread.start()
        done.wait()
    }

    /// Groups nested `depth` deep around a rectangle with a gradient, a star spec and a picture; the outermost first.
    static func chain(_ depth: Int) -> DesignNode {
        let asset = PlacedAsset(id: "asset-1", name: "photo.png", format: .png,
                                natural: Size(width: 1200, height: 800), data: Data([1, 2, 3]))
        var node = DesignNode(id: "leaf", name: "Photo", kind: .rectangle, frame: rc(0, 0, 10, 10),
                              gradient: .radial(stops: [], center: Point(x: 0.5, y: 0.5), radius: 1),
                              placedAsset: asset, placedFocus: Point(x: 0.2, y: 0.5))
        node.shape = ShapeSpec(kind: .star)
        for level in 0..<depth {
            node = DesignNode(id: "g\(level)", name: "Group", kind: .group, frame: rc(0, 0, 10, 10), children: [node])
        }
        return node
    }

    @Test func nodeStaysSmall() {
        FileHandle.standardError.write(Data(Self.sizes.utf8))
        #expect(MemoryLayout<DesignNode>.size <= 256, "\(Self.sizes)")
    }

    @Test func aDeepTreeFitsASmallStack() {
        FileHandle.standardError.write(Data(Self.sizes.utf8))  // before the thread: a crash loses buffered stdout
        let result = Locked()
        Self.onSmallStack(512) {
            let roots = [Self.chain(64)]
            let rows = roots.rows(expanded: Set((0..<64).map { "g\($0)" }))
            result.set(roots.layerTree.designNodes == roots && rows.count == 65 && rows.last?.node.shape?.kind == .star)
        }
        #expect(result.value == true)
    }

    @Test func aCopyKeepsItsOwnBoxedFields() {
        let original = Self.chain(0)
        var copy = original
        copy.shape = nil
        copy.gradient = nil
        copy.placedAsset = nil
        #expect(original.shape?.kind == .star)
        #expect(original.gradient != nil)
        #expect(original.placedAsset?.id == "asset-1" && original.placedFocus == Point(x: 0.2, y: 0.5))
        #expect(copy.shape == nil && copy.gradient == nil && copy.placedAsset == nil)
        #expect(copy != original)
    }
}

/// The thread's answer, read back after the semaphore.
private final class Locked: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Bool?
    var value: Bool? { lock.lock(); defer { lock.unlock() }; return stored }
    func set(_ ok: Bool) { lock.lock(); stored = ok; lock.unlock() }
}
