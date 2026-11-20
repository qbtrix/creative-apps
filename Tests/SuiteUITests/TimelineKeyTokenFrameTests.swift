// TimelineKeyTokenFrameTests.swift: a hosted TimelineStrip's key children, as the
// accessibility tree (and so XCUITest and the app audit) reads them. Each key is
// one token at its own tick, never a frame stretched over a neighbour
// (FlareLoopJourneys flare-loop-4-keyed: key 0 read 158 pt wide over key 24).
import AppKit
import SwiftUI
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineKeyTokenFrameTests {
    /// Rectangle 1 as the loop journey leaves it: keys at 0 and 24 of 48, the playhead on 24.
    @Test(arguments: [24, 0, 12])
    func eachKeyIsItsOwnTokenAtItsTick(playhead: Int) {
        let app = NSApplication.shared
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        // As in the journey: the lane holds key 0 alone, then a drag at 24 adds key 24.
        let holder = KeyFramesHolder()
        let host = NSHostingView(rootView: KeyTokenHost(holder: holder, playhead: playhead))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 80), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        _ = axButtons(in: window)
        holder.frames = [0, 24]
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        let keys = axButtons(in: window).filter { $0.id.hasPrefix("t.key.r.") }
        #expect(keys.map(\.id).sorted() == ["t.key.r.0", "t.key.r.24"])
        for key in keys {
            #expect(key.frame.width <= SuiteSize.timelineKeyframeHit + 0.5, "\(key.id) reads \(key.frame)")
        }
        if keys.count == 2 {
            #expect(!keys[0].frame.intersects(keys[1].frame), "\(keys[0].frame) overlaps \(keys[1].frame)")
        }
    }
}

@MainActor @Observable private final class KeyFramesHolder {
    var frames = [0]
}

private struct KeyTokenHost: View {
    let holder: KeyFramesHolder
    let playhead: Int
    var body: some View {
        let track = TimelineTrack(
            id: "r", name: "Rectangle 1", keys: holder.frames.map { TimelineKey(frame: $0, shape: .linear) },
            pickedFrames: [], isSelected: true)
        TimelineStrip(tracks: [track], duration: 48, frameWidth: 6, playhead: playhead)
            .environment(\.timelineIdentifierPrefix, "t")
            .frame(width: 600, height: 80)
    }
}
