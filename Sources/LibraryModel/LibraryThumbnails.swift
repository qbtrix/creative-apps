// LibraryThumbnails.swift: the grid's thumbnail state (feature thumbnails,
// TH-1). The cell's size bucket, requests for the visible cells only (never
// one twice, none for a file that can't be read), the develop token that lets
// a stale answer be dropped, and eviction that keeps visible ± two screens
// under 128 MB. Results (TH-2): stale answers dropped, failures to
// availability, invalidation. Each pass costs O(visible + held), not
// O(catalog) (TH-4): ThumbnailPositions finds an id in `items` and `order`.
// Linux-safe; LibraryApp runs the requests and hands back results.

/// A request's token: FNV-1a 64-bit over the develop settings' fields and the
/// long side. Deterministic across processes (never `hashValue`), so a result
/// rendered for settings that have since changed is recognised and dropped.
public enum ThumbnailToken {
    public static func of(_ develop: DevelopSettings, longSide: Int) -> Int {
        var hash = FNV1a()
        for slider in DevelopSlider.allCases { hash.add(word: develop.value(slider).bitPattern) }
        if let crop = develop.crop {
            hash.add(word: 1)
            for value in [crop.angle, crop.rect.x, crop.rect.y, crop.rect.width, crop.rect.height] {
                hash.add(word: value.bitPattern)
            }
            for byte in crop.aspect.rawValue.utf8 { hash.add(byte) }
        } else {
            hash.add(word: 0)
        }
        hash.add(word: UInt64(bitPattern: Int64(longSide)))
        return Int(truncatingIfNeeded: hash.value)
    }
}

/// FNV-1a 64-bit, fed bytes little-endian.
private struct FNV1a {
    private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325
    mutating func add(_ byte: UInt8) {
        value = (value ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
    }
    mutating func add(word: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) { add(UInt8(truncatingIfNeeded: word >> UInt64(shift))) }
    }
}

/// Where each id sits in `items` and in `order`. A cached position is used only
/// while that slot still holds the id; a miss rebuilds the map at most once per
/// pass, so a change to `items` or `order` (load, import, sort, collection,
/// filter) never has to update it.
struct ThumbnailPositions: Sendable {
    var items = IDPositions()
    var order = IDPositions()
}

/// One id → index map with checked hits.
struct IDPositions: Sendable {
    private var indices: [String: Int] = [:]

    /// The index of `id` in `ids`, or nil. `rebuilt` says whether this pass
    /// already rebuilt the map, so the answer after a rebuild is trusted.
    mutating func index<Ids: RandomAccessCollection>(of id: String, in ids: Ids, rebuilt: inout Bool) -> Int?
    where Ids.Element == String, Ids.Index == Int {
        if let index = indices[id], index >= ids.startIndex, index < ids.endIndex, ids[index] == id { return index }
        guard !rebuilt else { return nil }
        rebuilt = true
        indices = [:]
        indices.reserveCapacity(ids.count)
        for (index, key) in zip(ids.indices, ids) where indices[key] == nil { indices[key] = index }
        return indices[id]
    }
}

extension LibraryCatalog {
    /// The index of `id` in `items` (see ThumbnailPositions).
    mutating func itemIndex(of id: String, rebuilt: inout Bool) -> Int? {
        let ids = items.lazy.map(\.id)
        return thumbnailPositions.items.index(of: id, in: ids, rebuilt: &rebuilt)
    }

    /// The index of `id` in `order` (see ThumbnailPositions).
    mutating func orderIndex(of id: String, rebuilt: inout Bool) -> Int? {
        let ids = order
        return thumbnailPositions.order.index(of: id, in: ids, rebuilt: &rebuilt)
    }

    /// The most bytes of display images `thumbnails` holds after a request pass (128 MB).
    public static let heldThumbnailBytes = 128 * 1024 * 1024

    /// ThumbnailBucket for the cell; also sets `thumbnailLongSide`.
    public mutating func thumbnailLongSide(forCell cellWidth: Int, scale: Int) -> Int {
        thumbnailLongSide = ThumbnailBucket.longSide(forCell: cellWidth, scale: scale)
        return thumbnailLongSide
    }

    /// Requests for the visible ids that have no current image and no pending
    /// request; evicts held images outside visible ± two screens of `order`
    /// (never a visible one; an empty `visible`, as when the loupe opens, evicts nothing),
    /// farthest first, until `thumbnails` holds ≤ heldThumbnailBytes.
    public mutating func requestThumbnails(visible: [String]) -> [ThumbnailRequest] {
        let side = thumbnailLongSide
        var out: [ThumbnailRequest] = []
        var asked = Set<String>()
        var rebuilt = false
        for id in visible where asked.insert(id).inserted {
            guard let index = itemIndex(of: id, rebuilt: &rebuilt) else { continue }
            let photo = items[index]
            guard photo.availability == .available else { continue }
            if let held = thumbnails[id], held.size.longSide == photo.pixelSize.fitting(longSide: side).longSide {
                continue  // a develop change drops the held image first (invalidateThumbnail)
            }
            let token = ThumbnailToken.of(photo.develop, longSide: side)
            if pendingThumbnails[id]?.token == token { continue }
            let request = ThumbnailRequest(id: id, longSide: side, token: token)
            pendingThumbnails[id] = request
            out.append(request)
        }
        if !visible.isEmpty { evictThumbnails(around: asked) }
        return out
    }

    /// Drops held images outside `visible`'s span in `order` ± two screens,
    /// then the farthest from that span until the cap holds. A visible image stays.
    private mutating func evictThumbnails(around visible: Set<String>) {
        var low = Int.max, high = Int.min
        var rebuilt = false
        for id in visible {
            guard let index = orderIndex(of: id, rebuilt: &rebuilt) else { continue }
            low = min(low, index); high = max(high, index)
        }
        guard low <= high else { return }
        let margin = 2 * visible.count
        var candidates: [(id: String, distance: Int)] = []
        for id in thumbnails.keys where !visible.contains(id) {
            guard let index = orderIndex(of: id, rebuilt: &rebuilt) else { thumbnails[id] = nil; continue }  // not shown now
            let distance = index < low ? low - index : index > high ? index - high : 0
            if distance > margin { thumbnails[id] = nil } else { candidates.append((id, distance)) }
        }
        var bytes = thumbnails.values.reduce(0) { $0 + $1.rgba8.count }
        guard bytes > Self.heldThumbnailBytes else { return }
        for candidate in candidates.sorted(by: { $0.distance > $1.distance }) {
            guard bytes > Self.heldThumbnailBytes else { return }
            bytes -= thumbnails.removeValue(forKey: candidate.id)?.rgba8.count ?? 0
        }
    }

    /// Stores `image` while `request` is still the pending one for its photo and
    /// its token still matches the photo's develop settings. A stale answer is
    /// dropped: one for a request no longer pending changes nothing; one whose
    /// settings have since changed also clears the request, so the next pass asks again.
    public mutating func setThumbnail(_ image: DisplayImage, for request: ThumbnailRequest) {
        guard pendingThumbnails[request.id] == request else { return }
        pendingThumbnails[request.id] = nil
        var rebuilt = false
        guard let index = itemIndex(of: request.id, rebuilt: &rebuilt),
              ThumbnailToken.of(items[index].develop, longSide: request.longSide) == request.token
        else { return }
        thumbnails[request.id] = image
    }

    /// Clears the pending request; marks the photo `.missing` or `.unreadable(reason)`
    /// and drops any image it held. A failure for a request no longer pending is
    /// dropped, and `.cancelled` says nothing about the file, so it only clears the request.
    public mutating func failThumbnail(_ request: ThumbnailRequest, _ error: LibraryError) {
        guard pendingThumbnails[request.id] == request else { return }
        pendingThumbnails[request.id] = nil
        if case .cancelled = error { return }
        var rebuilt = false
        guard let index = itemIndex(of: request.id, rebuilt: &rebuilt) else { return }
        thumbnails[request.id] = nil
        if case .missingFile = error {
            items[index].availability = .missing
        } else {
            items[index].availability = .unreadable(error.message)
        }
    }

    /// Drops the held image and any pending request of `id` (after its develop
    /// settings change), so a late answer is dropped and the next pass asks again.
    public mutating func invalidateThumbnail(_ id: String) {
        thumbnails[id] = nil
        pendingThumbnails[id] = nil
    }
}
