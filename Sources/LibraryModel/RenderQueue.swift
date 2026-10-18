// RenderQueue.swift: runs the loupe's renders one at a time (loupe-viewport
// LV-3). A render submitted while another runs waits; a newer one replaces an
// older waiting one, so stepping quickly through photos renders the first
// and the last, never the ones skipped past. Linux-safe: no UI imports.

/// One render at a time, the latest submitted one waiting.
public actor RenderQueue {
    private struct Job {
        let token: Int
        let work: @Sendable () async -> Void
    }

    private var running = false
    private var waiting: Job?

    public init() {}

    /// Runs `work` now when nothing runs, and then whatever is waiting once it
    /// ends; returns when the queue is idle again. While another render runs,
    /// `work` becomes the waiting one, dropping any older waiting one, and
    /// this returns at once.
    public func submit(token: Int, _ work: @escaping @Sendable () async -> Void) async {
        guard !running else {
            waiting = Job(token: token, work: work)
            return
        }
        running = true
        await work()
        while let next = waiting {
            waiting = nil
            await next.work()
        }
        running = false
    }
}
