// FakeHits.swift: StageHitTesting by bounding box on FakeStage's draw list, instances included (blueprint 6.3).
// A world box is the path's box through the item's transform, grown by half its stroke width. Text items and
// locked layers are never hit nor bounded (hidden ones are not listed); with `unavailable` set, nothing is.
import FlareCore

public struct FakeHits: StageHitTesting {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    public func hit(_ document: Document, sceneID: String, frame: Int, at point: Point,
                    tolerance: Double) -> StageAddress? {
        let pad = tolerance.isFinite ? max(tolerance, 0) : 0
        let probe = Rect(minX: point.x - pad, minY: point.y - pad, maxX: point.x + pad, maxY: point.y + pad)
        return hittable(document, sceneID, frame).last { Self.overlap($0.rect, probe) }?.address
    }

    public func marquee(_ document: Document, sceneID: String, frame: Int, rect: Rect) -> [StageAddress] {
        var found: [StageAddress] = []
        for box in hittable(document, sceneID, frame) where !found.contains(box.address) && Self.overlap(box.rect, rect) {
            found.append(box.address)
        }
        return found
    }

    /// Whether `a` and `b` share a point, edges included.
    private static func overlap(_ a: Rect, _ b: Rect) -> Bool {
        a.minX <= b.maxX && a.maxX >= b.minX && a.minY <= b.maxY && a.maxY >= b.minY
    }

    public func bounds(_ document: Document, sceneID: String, frame: Int, of items: [StageAddress]) -> Rect? {
        let boxes = hittable(document, sceneID, frame).filter { items.contains($0.address) }.map(\.rect)
        return Rect(enclosing: boxes.flatMap { [Point(x: $0.minX, y: $0.minY), Point(x: $0.maxX, y: $0.maxY)] })
    }

    /// Every hittable item's world box, bottom first.
    private func hittable(_ document: Document, _ sceneID: String, _ frame: Int) -> [(address: StageAddress, rect: Rect)] {
        guard unavailable == nil else { return [] }
        return FakeStage().drawList(document, sceneID: sceneID, frame: frame, editing: nil).items.compactMap { item in
            guard !item.isText, let rect = Self.worldBox(item) else { return nil }
            let layer = document.layers(of: item.address.owner)?.first { $0.id == item.address.layerID }
            return layer?.isLocked == true ? nil : (item.address, rect)
        }
    }

    /// The item's path box through its transform, grown by half its stroke width; nil for an empty path.
    private static func worldBox(_ item: StageItem) -> Rect? {
        guard let local = item.path.bounds else { return nil }
        let corners = [Point(x: local.minX, y: local.minY), Point(x: local.maxX, y: local.minY),
                       Point(x: local.minX, y: local.maxY), Point(x: local.maxX, y: local.maxY)]
        guard let box = Rect(enclosing: corners.map(item.transform.apply)) else { return nil }
        let half = (item.stroke?.width ?? 0) / 2
        return Rect(minX: box.minX - half, minY: box.minY - half, maxX: box.maxX + half, maxY: box.maxY + half)
    }
}
