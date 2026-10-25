// RenderQueue.swift: runs the loupe's renders one at a time (loupe-viewport
// LV-3). A render submitted while another runs waits; a newer one replaces an
// older waiting one, so stepping quickly through photos renders the first
// and the last, never the ones skipped past. A render can bring the photos
// beside the loupe's to decode ahead (large-catalog LG-6, #3109): they run
// one at a time once no render waits, and a newer step's neighbours replace
// the older step's pending ones, so a stale decode never runs or evicts the
// focus's. Linux-safe: no UI imports.

/// One render at a time, the latest submitted one waiting, then the neighbours.
public actor RenderQueue {
    private struct Job {
        let token: Int
        let work: @Sendable () async -> Void
    }

    /// The photos to decode ahead of the next step, and how to decode one.
    public struct Ahead: Sendable {
        public let photos: [PhotoItem]
        public let decode: @Sendable (PhotoItem) async -> Void

        public init(_ photos: [PhotoItem], decode: @escaping @Sendable (PhotoItem) async -> Void) {
            self.photos = photos; self.decode = decode
        }
    }

    private var running = false
    private var waiting: Job?
    private var ahead: Ahead?

    public init() {}

    /// Runs `work` now when nothing runs, then whatever is waiting, then the
    /// pending neighbours, a waiting render always before the next decode;
    /// returns when the queue is idle again. While another render runs,
    /// `work` becomes the waiting one, dropping any older waiting one, and
    /// this returns at once. `prefetching` replaces the pending neighbours;
    /// nil keeps them (a develop drag's render on the same photo).
    public func submit(token: Int, prefetching: Ahead? = nil, _ work: @escaping @Sendable () async -> Void) async {
        if let prefetching { ahead = prefetching }
        guard !running else {
            waiting = Job(token: token, work: work)
            return
        }
        running = true
        await work()
        while let next = nextStep() {
            await next()
        }
        running = false
    }

    /// The waiting render, else the next neighbour's decode (taken off the
    /// pending list); nil when both are empty.
    private func nextStep() -> (@Sendable () async -> Void)? {
        if let next = waiting {
            waiting = nil
            return next.work
        }
        guard let pending = ahead, let photo = pending.photos.first else { return nil }
        let rest = Array(pending.photos.dropFirst())
        ahead = rest.isEmpty ? nil : Ahead(rest, decode: pending.decode)
        return { await pending.decode(photo) }
    }
}
