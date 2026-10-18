// LibraryThumbnails.swift: the grid's thumbnail state (feature thumbnails,
// TH-1). The cell's size bucket, requests for the visible cells only (never
// one twice, none for a file that can't be read), the develop token that lets
// a stale answer be dropped, and eviction that keeps visible ± two screens
// under 128 MB. Results (TH-2): stale answers dropped, failures to
// availability, invalidation. The whole display scale the grid reports with
// its cell size (TH-6f). Linux-safe; LibraryApp runs the requests and hands
// back results.

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

extension LibraryCatalog {
    /// The most bytes of display images `thumbnails` holds after a request pass (128 MB).
    public static let heldThumbnailBytes = 128 * 1024 * 1024

    /// The whole display scale a cell's bucket is chosen at: the window's
    /// display scale rounded, clamped to 1...8 (0, a negative, NaN or
    /// infinite scale is 1), so the grid never reports a scale it can't use.
    public static func thumbnailScale(forDisplayScale scale: Double) -> Int {
        guard scale.isFinite else { return 1 }
        return Int(min(max(scale.rounded(), 1), 8))
    }

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
        let wanted = Set(visible)
        var photos: [String: PhotoItem] = [:]
        for photo in items where wanted.contains(photo.id) { photos[photo.id] = photo }
        var out: [ThumbnailRequest] = []
        var asked = Set<String>()
        for id in visible where asked.insert(id).inserted {
            guard let photo = photos[id], photo.availability == .available else { continue }
            if let held = thumbnails[id], held.size.longSide == photo.pixelSize.fitting(longSide: side).longSide {
                continue  // a develop change drops the held image first (invalidateThumbnail)
            }
            let token = ThumbnailToken.of(photo.develop, longSide: side)
            if pendingThumbnails[id]?.token == token { continue }
            let request = ThumbnailRequest(id: id, longSide: side, token: token)
            pendingThumbnails[id] = request
            out.append(request)
        }
        if !visible.isEmpty { evictThumbnails(around: wanted) }
        return out
    }

    /// Drops held images outside `visible`'s span in `order` ± two screens,
    /// then the farthest from that span until the cap holds. A visible image stays.
    private mutating func evictThumbnails(around visible: Set<String>) {
        var low = Int.max, high = Int.min
        var positions: [String: Int] = [:]
        for (index, id) in order.enumerated() {
            if visible.contains(id) { low = min(low, index); high = max(high, index) }
            if thumbnails[id] != nil { positions[id] = index }
        }
        guard low <= high else { return }
        let margin = 2 * visible.count
        var candidates: [(id: String, distance: Int)] = []
        for id in thumbnails.keys where !visible.contains(id) {
            guard let index = positions[id] else { thumbnails[id] = nil; continue }  // not shown now
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
        guard let photo = items.first(where: { $0.id == request.id }),
              ThumbnailToken.of(photo.develop, longSide: request.longSide) == request.token
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
        guard let index = items.firstIndex(where: { $0.id == request.id }) else { return }
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
