// Live/LiveCulling.swift: the live rating, flag and label rules (cull,
// CU-2). `apply` changes the photos whose ids are given and refuses a rating
// outside 0...5; `advance` is the full Auto Advance rule, which also handles
// a change that hides the photo under the current filter.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveCulling: PhotoCulling {
    public static let unavailable: String? = nil
    public init() {}

    /// The plain rules, shared with `FakeCulling` in its `.ok` mode (which
    /// never throws its preview message): it refuses a rating outside 0...5.
    public func apply(_ change: CullChange, to ids: Set<String>, in items: [PhotoItem]) throws -> [PhotoItem] {
        try FakeCulling(mode: .ok).apply(change, to: ids, in: items)
    }

    /// The next shown photo after `id`, or `id` when it was the last one
    /// shown. When the change hid `id`, the photo that took its place: the
    /// first later photo still shown, else the nearest earlier one.
    public func advance(from id: String, before: [String], after: [String]) -> String? {
        guard !after.isEmpty else { return nil }
        guard let index = before.firstIndex(of: id) else { return after.first }
        let shown = Set(after)
        let next = before[(index + 1)...].first { shown.contains($0) }
        if shown.contains(id) { return next ?? id }
        return next ?? before[..<index].last { shown.contains($0) }
    }
}
