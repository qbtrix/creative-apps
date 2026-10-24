// PhotoRetouchRelease.swift (fill-heal FH-8): what the Paint Bucket, Spot
// Heal and Remove tools do when the pointer lifts. Their drag only holds the
// press (and Remove's path, PhotoRetouchMarks.swift); `endDrag` runs one
// catalog command, so a click or a whole stroke is one undo step: the bucket
// fills the region under the press (`fill.bucket`, with the options bar's
// Tolerance, Contiguous and All Layers), Spot Heal rebuilds the spot under
// the press at the brush's size (`retouch.spot-heal`) and Remove fills what
// the stroke passed over (`retouch.remove`). A command that can't run leaves
// the layer as it was and says why in the status line. Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace {
    /// The catalog command a retouch tool's release runs, and its params;
    /// nil for any other tool.
    static func retouchCommand(
        _ done: PhotoStroke, size: Double, bucket: BucketOptions
    ) -> (id: String, params: JSONValue)? {
        let size = JSONValue.number(min(max(size.isNaN ? 1 : size, 1), 500))
        let x = JSONValue.number(done.start.x), y = JSONValue.number(done.start.y)
        switch done.tool {
        case .bucket:
            return ("fill.bucket", .object([
                "x": x, "y": y, "tolerance": .number(Double(bucket.tolerance)),
                "contiguous": .bool(bucket.contiguous), "allLayers": .bool(bucket.sampleAllLayers),
            ]))
        case .spotHeal:
            return ("retouch.spot-heal", .object(["x": x, "y": y, "size": size]))
        case .remove:
            let path = done.path.isEmpty ? [done.start] : done.path
            let points = path.filter { $0.x.isFinite && $0.y.isFinite }.prefix(100_000)
            return ("retouch.remove", .object([
                "points": .array(points.map { .object(["x": .number($0.x), "y": .number($0.y)]) }), "size": size,
            ]))
        default:
            return nil
        }
    }

    /// The release of a Paint Bucket, Spot Heal or Remove drag: its command,
    /// once, as one undo step, or the reason it can't run in `statusMessage`.
    mutating func retouchRelease(_ done: PhotoStroke) {
        guard let command = Self.retouchCommand(done, size: brushOptions.size, bucket: bucketOptions) else { return }
        do { _ = try Self.catalog.run(command.id, params: command.params, on: &self) } catch {
            if case .unavailable(_, let why) = error { statusMessage = why } else { statusMessage = "Couldn't do that there." }
        }
    }
}
