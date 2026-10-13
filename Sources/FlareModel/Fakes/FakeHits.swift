// FakeHits.swift: StageHitTesting by bounding box on FakeStage's draw list, instances included
// (docs/blueprints/flare.md, 6.3). An item's world box is its path's box through its transform, grown by
// half its stroke width. Text items and locked layers are never hit; hidden layers are not on the list.
// With `unavailable` set, nothing is hit and there are no bounds.
import FlareCore

public struct FakeHits: StageHitTesting {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    public func hit(_ document: Document, sceneID: String, frame: Int, at point: Point,
                    tolerance: Double) -> StageAddress? {
        let pad = tolerance.isFinite ? max(tolerance, 0) : 0
        return hittable(document, sceneID, frame).last { box in
            point.x >= box.rect.minX - pad && point.x <= box.rect.maxX + pad
                && point.y >= box.rect.minY - pad && point.y <= box.rect.maxY + pad
        }?.address
    }

    public func marquee(_ document: Document, sceneID: String, frame: Int, rect: Rect) -> [StageAddress] {
        var found: [StageAddress] = []
        for box in hittable(document, sceneID, frame) where !found.contains(box.address)
            && box.rect.minX <= rect.maxX && box.rect.maxX >= rect.minX
            && box.rect.minY <= rect.maxY && box.rect.maxY >= rect.minY {
            found.append(box.address)
        }
        return found
    }

    public func bounds(_ document: Document, sceneID: String, frame: Int, of items: [StageAddress]) -> Rect? {
        guard unavailable == nil else { return nil }
        let boxes = FakeStage().drawList(document, sceneID: sceneID, frame: frame, editing: nil).items
            .filter { items.contains($0.address) }.compactMap(Self.worldBox)
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
