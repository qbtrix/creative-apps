// FlareOpenStatus.swift: an open's progress row (layers-files LF-4, QB-L9).
// While `model.loadState` is `.loading`, SuiteUI's BusyNote "Opening…"
// (`flare.open.progress`) shows over the stage area once `showsLoadProgress` says
// `loadProgressDelay` (100 ms) has passed, so a fast open never flashes it.
// The modifier notes when loading began and checks every 50 ms through a
// TimelineView that exists only while loading. A snapshot pins the start
// through `\.flareOpenStartedAt`. A failed open's alert stays FlareFilePanels'.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareOpenStatus: ViewModifier {
    let model: FlareWorkspace
    @Environment(\.flareOpenStartedAt) private var pinnedStart
    @State private var began: Double?

    private var loading: Bool { model.loadState == .loading }

    func body(content: Content) -> some View {
        content
            .overlay {
                if loading {
                    TimelineView(.periodic(from: .now, by: 0.05)) { context in
                        let now = context.date.timeIntervalSinceReferenceDate
                        if model.showsLoadProgress(startedAt: pinnedStart ?? began ?? now, now: now) {
                            BusyNote("Opening…", identifier: "flare.open.progress")
                        }
                    }
                }
            }
            .onChange(of: loading, initial: true) { _, isLoading in
                began = isLoading ? Date.now.timeIntervalSinceReferenceDate : nil
            }
    }
}

extension EnvironmentValues {
    /// The open's start time (seconds since the reference date) when a snapshot
    /// pins it; nil uses the time loading began.
    @Entry var flareOpenStartedAt: Double? = nil
}
