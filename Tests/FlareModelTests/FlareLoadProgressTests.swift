// FlareLoadProgressTests.swift: when the open progress row shows (FlareLoadProgress.swift; layers-files LF-4,
// QB-L9). While an open is loading the row waits `loadProgressDelay` (100 ms) and then shows; a fast open never
// flashes it, and an idle or failed open never shows it. Runs on Linux and macOS.
import FlareModel
import Testing

@Suite struct FlareLoadProgressTests {
    private func loading() -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .fake())
        workspace.beginOpen()
        return workspace
    }

    @Test func theDelayIsAHundredMilliseconds() {
        #expect(FlareWorkspace.loadProgressDelay == 0.1)
    }

    @Test func loadingForFiftyMillisecondsShowsNothing() {
        let workspace = loading()
        #expect(!workspace.showsLoadProgress(startedAt: 10, now: 10))
        #expect(!workspace.showsLoadProgress(startedAt: 10, now: 10.05))
        #expect(!workspace.showsLoadProgress(startedAt: 10, now: 10.099))
    }

    @Test func loadingForAHundredMillisecondsShowsTheRow() {
        let workspace = loading()
        #expect(workspace.showsLoadProgress(startedAt: 0, now: 0.1))
        #expect(workspace.showsLoadProgress(startedAt: 10, now: 10.1))
        #expect(workspace.showsLoadProgress(startedAt: 1_000_000, now: 1_000_000.1))
        #expect(workspace.showsLoadProgress(startedAt: 10, now: 12))
    }

    @Test func idleNeverShowsTheRow() {
        let workspace = FlareWorkspace(services: .fake())
        #expect(workspace.loadState == .idle)
        #expect(!workspace.showsLoadProgress(startedAt: 0, now: 0.1))
        #expect(!workspace.showsLoadProgress(startedAt: 0, now: 60))
    }

    @Test func aFailedOpenNeverShowsTheRow() {
        var workspace = loading()
        workspace.finishOpen(.failure(.notAFlareFile), named: "bad.flare")
        #expect(workspace.loadState == .failed("This file isn't a Flare animation."))
        #expect(!workspace.showsLoadProgress(startedAt: 0, now: 1))
    }

    @Test func aClockGoingBackOrNotFiniteShowsNothing() {
        let workspace = loading()
        #expect(!workspace.showsLoadProgress(startedAt: 10, now: 9))
        #expect(!workspace.showsLoadProgress(startedAt: .nan, now: 1))
        #expect(!workspace.showsLoadProgress(startedAt: 0, now: .infinity))
    }
}
