// PhotoTileUpdate.swift: what the live canvas needs after an edit, the canvas
// tiles that changed and nothing else. `PhotoRenderer.update(_:since:)`
// renders the tiles damaged since the revision the canvas shows, in parallel,
// as premultiplied 8-bit sRGB (what Core Animation draws without converting),
// so a brush event costs its dirty tiles, never a copy of the whole canvas.
// With no revision shown (a new image, a new size) every tile comes, and the
// update says it is complete. The full-frame `render` stays the reference: the
// tiles laid where they belong equal its bytes, premultiplied the same way
// (`premultiplied(_:)`). Linux-safe.
import CoreRaster

/// The canvas tiles that changed, ready for display.
public struct PhotoTileUpdate: Sendable {
    public struct Tile: Sendable, Equatable {
        /// Where the tile sits on the canvas, in pixels.
        public let rect: PixelRect
        /// rect.width x rect.height x 4 bytes, row-major, sRGB, premultiplied alpha.
        public let rgba8: [UInt8]
    }

    /// The canvas size the tiles belong to.
    public let width: Int
    public let height: Int
    public let revision: Int
    /// Whether `tiles` covers the whole canvas, so tiles shown before are stale.
    public let isComplete: Bool
    public let tiles: [Tile]
    public let milliseconds: Double
}

extension PhotoRenderer {
    /// The tiles of `workspace` damaged since `revision`, or all of them with
    /// no revision. Throws `RasterError` with no image open or when an
    /// adjustment fails.
    public static func update(_ workspace: PhotoWorkspace, since revision: Int?) async throws -> PhotoTileUpdate {
        guard let canvas = workspace.canvas else { throw RasterError.invalid("no image is open") }
        let clock = ContinuousClock()
        let started = clock.now
        let damage = revision.map { workspace.damage(since: $0) } ?? .all
        let tiles = try await renderedTiles(workspace, tiles(of: canvas, in: damage), premultiplied: true)
        let elapsed = clock.now - started
        return PhotoTileUpdate(
            width: canvas.width, height: canvas.height, revision: workspace.revision, isComplete: damage == .all,
            tiles: tiles.map { PhotoTileUpdate.Tile(rect: $0, rgba8: $1) },
            milliseconds: Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15)
    }

    /// Every tile of `workspace`, rendered one after another on the caller's
    /// thread, for a picture that can wait (snapshots). Throws as `update` does.
    public static func completeUpdate(_ workspace: PhotoWorkspace) throws -> PhotoTileUpdate {
        guard let canvas = workspace.canvas else { throw RasterError.invalid("no image is open") }
        let tiles = try tiles(of: canvas, in: .all).map { rect in
            var bytes = try workspace.rendered(rect).rgba8()
            premultiply(&bytes)
            return PhotoTileUpdate.Tile(rect: rect, rgba8: bytes)
        }
        return PhotoTileUpdate(
            width: canvas.width, height: canvas.height, revision: workspace.revision, isComplete: true, tiles: tiles,
            milliseconds: 0)
    }

    /// Straight-alpha RGBA bytes premultiplied, each color rounded to the
    /// nearest of `color x alpha / 255`. Opaque pixels stay as they are.
    public static func premultiplied(_ rgba8: [UInt8]) -> [UInt8] {
        var bytes = rgba8
        premultiply(&bytes)
        return bytes
    }

    /// `premultiplied(_:)` in place.
    static func premultiply(_ bytes: inout [UInt8]) {
        bytes.withUnsafeMutableBufferPointer { p in
            for i in stride(from: 0, to: p.count - 3, by: 4) where p[i + 3] != 255 {
                let a = UInt32(p[i + 3])
                for c in i..<(i + 3) { p[c] = UInt8((UInt32(p[c]) * a + 127) / 255) }
            }
        }
    }
}
