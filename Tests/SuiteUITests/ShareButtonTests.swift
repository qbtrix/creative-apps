// ShareButtonTests.swift: SuiteUI's ShareButton (share-sheet SH-2): disabled with
// the host's reason while it can't share, a spinner and no second press while
// preparing, "Share N Photos" once the files are ready, and a prepare that throws
// or returns nothing says why instead of sharing nothing. macOS only.
import AppKit
import Foundation
@testable import SuiteUI
import SwiftUI
import Testing

private struct Refused: LocalizedError {
    var errorDescription: String? { "Sharing arrives with SH-3." }
}

@MainActor @Suite struct ShareButtonTests {
    let files = ["/s/Share/r1/IMG_0001.jpg", "/s/Share/r1/IMG_0002.jpg"].map { URL(fileURLWithPath: $0) }

    @Test func disabledWithTheReasonWhenNothingIsSelected() {
        let help = "Select a photo to share it."
        #expect(SharePhase.idle.isEnabled(help: help) == false)
        #expect(SharePhase.idle.tooltip(help: help) == help)
        #expect(SharePhase.ready(files).tooltip(help: help) == help)
        #expect(SharePhase.idle.isEnabled(help: nil))
        #expect(SharePhase.idle.title == "Share…")
    }

    @Test func showsProgressWhilePreparing() {
        #expect(SharePhase.preparing.isEnabled(help: nil) == false)
        #expect(SharePhase.preparing.tooltip(help: nil) == "Preparing the photos to share…")
    }

    @Test func readyNamesHowManyPhotos() {
        #expect(SharePhase.finished(.success(files)) == .ready(files))
        #expect(SharePhase.ready(files).title == "Share 2 Photos")
        #expect(SharePhase.ready(Array(files.prefix(1))).title == "Share 1 Photo")
    }

    @Test func aFailedOrEmptyPrepareSaysWhy() {
        #expect(SharePhase.finished(.failure(Refused())) == .failed("Sharing arrives with SH-3."))
        #expect(SharePhase.finished(.success([])) == .failed("There was nothing to share."))
        #expect(SharePhase.failed("Disk full.").tooltip(help: nil) == "Disk full.")
        #expect(SharePhase.failed("Disk full.").isEnabled(help: nil))
    }

    @Test func itDraws() {
        for help in [nil, "Select a photo to share it."] {
            let host = NSHostingView(rootView: ShareButton(help: help) { [] })
            host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize.width > 0 && host.fittingSize.height > 0)
        }
    }
}
