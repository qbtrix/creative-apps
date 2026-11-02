// HaloLiveEdit.swift: the project a drag shows while it lasts, out of the
// window's State. Every write to the window's HaloProject re-runs HaloWindow
// and lays out the whole window (sidebar, menus, every lane and row), so a
// viewer drag or an inspector scrub that wrote the project per mouse sample
// ran the window per sample. Instead each sample puts the window's current
// project with that sample applied (through the Model's own methods, `show`)
// here, and only the views that read `project` re-run: the viewer's drawn
// layers. A view that previews this way needs no project of its own, so the
// inspector's rows compare as plain values and skip frames that leave them
// unchanged. The drag's
// end sends its last value to the window as before, so the window changes
// once and records one step. HaloWindow owns one and hands it down as the
// `haloLiveEdit` environment value; without one (a view hosted alone) a drag
// writes the window per sample, as it used to. A playing tick lands in
// `playing` the same way (#4274), so it re-runs only the leaves that read
// `shown(_:)` (drawn layers, handles, playhead, timecode, HaloLiveShown),
// never the window, lanes or inspector; so does a ruler scrub (#4448). The
// window takes the frame back (`takePlayback`) before any other command, and
// a scrub's once the drag rests (`settle`). Presentation state only.
import HaloModel
import Observation
import SuiteUI
import SwiftUI

@MainActor @Observable final class HaloLiveEdit {
    /// The window's project with the live drag's latest sample applied; nil
    /// with no drag live.
    var project: HaloProject?
    /// The window's project now; HaloWindow sets it once it appears.
    @ObservationIgnored var current: @MainActor () -> HaloProject? = { nil }
    /// The window's project ticked to the frame playing now, or scrubbed to
    /// the ruler's frame; nil with neither live.
    var playing: HaloProject?
    /// The tick or scrub `playing` shows, for the window to take it back.
    @ObservationIgnored var playhead = HaloLivePlayhead()
    /// The deferred take-back of a ruler drag that has rested.
    @ObservationIgnored private var settling: Task<Void, Never>?
    /// The window's `haloRefreshLink`, which HaloWindow's RefreshLinkHandoff sets once it appears;
    /// an inspector scrub paces its writes on it. A row reading the closure
    /// from the environment would re-run whenever the window does, since
    /// SwiftUI can't compare closures.
    @ObservationIgnored var makeLink: SuitePlaybackDriver.LinkMaker = SuiteScreenLink.make

    /// What a viewer shows of `model`: the live drag's project, else the
    /// playing frame, else `model` itself.
    func shown(_ model: HaloProject) -> HaloProject { project ?? playing ?? model }

    /// Shows the window's current project with `change` applied; nothing
    /// before the window has set `current`.
    func show(_ change: (inout HaloProject) -> Void) {
        guard var shown = current() else { return }
        change(&shown)
        project = shown
    }

    /// Runs `take` once nothing has called this for `seconds`: a ruler drag
    /// that rests (or ends) writes its frame back once.
    func settle(after seconds: Double, _ take: @escaping @MainActor () -> Void) {
        settling?.cancel()
        settling = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            self.settling = nil
            take()
        }
    }

    /// Drops a pending `settle`.
    func cancelSettle() {
        settling?.cancel()
        settling = nil
    }
}

/// `content` on what the window's live edit shows of `model` (HaloLiveEdit
/// `shown`), so only this leaf re-runs when a drag sample or a playing frame
/// lands; `model` itself outside a HaloWindow.
struct HaloLiveShown<Content: View>: View {
    let model: HaloProject
    @ViewBuilder let content: (HaloProject) -> Content
    @Environment(\.haloLiveEdit) private var live

    var body: some View { content(live?.shown(model) ?? model) }
}

extension EnvironmentValues {
    /// The window's live drag; nil outside a HaloWindow.
    @Entry var haloLiveEdit: HaloLiveEdit?
}
