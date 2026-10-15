// HaloWindowSnapshots.swift: Halo's whole window as it opens, on a new
// HaloProject with no compositions, at its launch size (SuiteSize.windowLaunch)
// in the top leading corner of the 1440x900 frame, in Light and Dark. Writes
// halo-window-launch-light.png and halo-window-launch-dark.png. macOS only.
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloWindowSnapshots {
    @Test func launch() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloWindow()
                    .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "halo-window-launch-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
