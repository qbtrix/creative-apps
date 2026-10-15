// LiveHits+Marquee.swift: live hit testing, part two (docs/blueprints/flare/features/live-stage.md, task ST-4).
// `marquee` asks FlareCore's render list for the items a rect touches (LC-2): paint order, locked and text items
// skipped, hidden layers absent; the edited symbol's own list while one is edited in place. Anything inside an
// instance answers once, as that instance. `bounds` is the union of the core's stroke-inclusive world bounds (LC-3)
// of every render item behind the given stage addresses; nil for none. With both, `LiveHits` is `StageHitTesting`.
import FlareCore

extension LiveHits {
    /// The unlocked, visible, non-text items `rect` touches, in paint order, each stage address once; [] on an
    /// unknown scene or symbol, or a rect with no area.
    public func marquee(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?,
                        rect: Rect) -> [StageAddress] {
        guard let list = Self.renderList(document, sceneID, frame, symbolID) else { return [] }
        var picked: [StageAddress] = []
        for address in list.marquee(rect).compactMap(Self.address) where !picked.contains(address) {
            picked.append(address)
        }
        return picked
    }

    /// The scene-space box of `items`, stroke included; nil when none of them has a box.
    public func bounds(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?,
                       of items: [StageAddress]) -> Rect? {
        guard !items.isEmpty, let list = Self.renderList(document, sceneID, frame, symbolID) else { return nil }
        let wanted = list.items.map(\.address).filter { core in Self.address(core).map(items.contains) ?? false }
        return list.worldBounds(of: wanted)
    }
}

extension LiveHits: StageHitTesting {}
