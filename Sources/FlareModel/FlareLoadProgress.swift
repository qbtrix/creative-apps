// FlareLoadProgress.swift: when the window shows an open's progress row (docs/blueprints/flare.md, section 3.3;
// layers-files LF-4, QB-L9). The row waits `loadProgressDelay` after `beginOpen`, so a fast open never flashes it,
// and shows only while `loadState` is `.loading`. The app keeps the time the open started and asks with its clock.
extension FlareWorkspace {
    /// Seconds an open runs before its progress row shows.
    public static let loadProgressDelay = 0.1

    /// True while an open is loading and `loadProgressDelay` has passed since `startedAt`. False when idle or
    /// failed, before the delay, and for a non-finite time.
    public func showsLoadProgress(startedAt: Double, now: Double) -> Bool {
        guard loadState == .loading, startedAt.isFinite, now.isFinite else { return false }
        // The tolerance keeps exactly 100 ms on time when the seconds since the start can't be held exactly.
        return now - startedAt + 1e-9 >= Self.loadProgressDelay
    }
}
