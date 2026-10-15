// PhotoRetouchDabTests.swift: a clone or heal drag lays each dab once
// (photo-seams r1). A continuation event starts where the previous event's
// last dab landed, so it lays only the dabs after that point; the press still
// lays its first dab at the start. The skipped dab changed no pixel, so a
// stroke paints exactly what it did when the dab was stamped twice: the
// digests below were recorded before the change. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Synchronization
import Testing

@Suite struct PhotoRetouchDabTests {
    /// Counts the coverage lookups a dab makes: one per pixel of its box.
    private final class Lookups: Sendable {
        private let count = Mutex(0)
        var value: Int { count.withLock { $0 } }
        func add() { count.withLock { $0 += 1 } }
    }

    /// A 256 x 256 white image with a red line along y = 40 and a green
    /// one along x = 60, the tool selected with a 64 px brush and the source
    /// sampled at (60, 40).
    private func textured(_ tool: PhotoTool) throws -> PhotoWorkspace {
        var workspace = try whiteImage(256, 256)
        workspace.setToolOption(.size(8))
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        stroke(&workspace, .brush, from: point(0, 40), to: point(255, 40))
        workspace.setToolOption(.color(red: 0, green: 200, blue: 0))
        stroke(&workspace, .brush, from: point(60, 0), to: point(60, 255))
        workspace.selectTool(tool)
        workspace.setToolOption(.size(64))
        workspace.setCloneSource(at: point(60, 40))
        return workspace
    }

    /// The coverage lookups of each event of a drag from (120, 120) moving
    /// 6 px right per event, the press first.
    private func lookupsPerEvent(_ tool: PhotoTool, events: Int) throws -> [Int] {
        var workspace = try textured(tool)
        let lookups = Lookups()
        var counts: [Int] = []
        PhotoWorkspace.$forcedCoverage.withValue({ _, _ in lookups.add(); return 1 }) {
            var at = point(120, 120)
            for _ in 0...events {
                let from = at
                at = point(at.x + 6, at.y)
                let start = lookups.value
                workspace.drag(from: from, to: at)
                counts.append(lookups.value - start)
            }
            workspace.endDrag()
        }
        return counts
    }

    @Test(arguments: [PhotoTool.clone, .heal])
    func aContinuationEventLaysOneNewDab(tool: PhotoTool) throws {
        let counts = try lookupsPerEvent(tool, events: 5)
        // The press lays a dab at its start and one 6 px on: two boxes.
        let box = try #require(counts.first) / 2
        #expect(box > 0)
        // Each 6 px move with a 16 px spacing lays one new dab: one box.
        #expect(counts.dropFirst().allSatisfy { $0 == box }, "\(tool): \(counts), one box is \(box)")
    }

    /// FNV-1a, 64-bit, over each channel's bits: a stable digest of a layer.
    private func digest(_ tiled: TiledPixels) throws -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for y in 0..<tiled.height {
            for x in 0..<tiled.width {
                let p = try tiled.pixel(x: x, y: y)
                for bits in [p.r.bitPattern, p.g.bitPattern, p.b.bitPattern, p.a.bitPattern] {
                    hash = (hash ^ UInt64(bits)) &* 1_099_511_628_211
                }
            }
        }
        return hash
    }

    /// A stroke of 12 events of varied length and direction, so dabs overlap.
    private func strokeDigest(_ tool: PhotoTool) throws -> UInt64 {
        var workspace = try textured(tool)
        var at = point(150, 150)
        for (dx, dy) in [(6.0, 0.0), (3, 2), (11, -4), (0, 9), (-5, 5), (17, 1), (2, 2), (-9, -12), (4, 0), (6, 6),
                         (1, 0), (25, -3)]
        {
            let from = at
            at = point(at.x + dx, at.y + dy)
            workspace.drag(from: from, to: at)
        }
        workspace.endDrag()
        return try digest(try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] }))
    }

    @Test func aCloneStrokePaintsAsBefore() throws {
        #expect(try strokeDigest(.clone) == 815_667_525_877_601_971)
    }

    @Test func aHealStrokePaintsAsBefore() throws {
        #expect(try strokeDigest(.heal) == 7_887_995_755_704_010_076)
    }
}
