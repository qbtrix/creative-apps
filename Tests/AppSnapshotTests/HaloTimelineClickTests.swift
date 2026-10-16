// HaloTimelineClickTests.swift: what a mouse click on Halo's timeline sends.
// It hosts HaloTimelineView on the `keyed` fixture (Ball keyed at 0, 12 and
// 24 over Floor) in an 800 x 400 borderless window ordered in far off every
// screen, as PhotoWindowStrokeTests hosts PhotoWindow, records the commands
// it sends to `perform`, and clicks with real mouse events where a person
// would: on Floor's span bar away from any key, which selects Floor as a
// click on its name does (B5 in the 2026-10-16 timeline review), and on
// Ball's diamond at 24, which picks that lane's keys at 24. Points come from
// HaloTimelineLayout and the Model's frame width, plus the strip's 8 pt inset
// before frame 0 (SuiteSpacing.s). macOS only.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor @Suite struct HaloTimelineClickTests {
    @Test func aBarClickSelectsItsLayerAndADiamondClickPicksItsKeys() async throws {
        let project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let rows = project.timelineRows
        let ball = try #require(rows.firstIndex { $0.name == "Ball" })
        let floor = try #require(rows.firstIndex { $0.name == "Floor" })
        let comp = try #require(project.selectedComposition)
        let size = CGSize(width: 800, height: 400)
        let layout = HaloTimelineView.layout
        let frameWidth = comp.frameWidth(toFit: layout.laneFitWidth(width: size.width))
        let sent = Sent()
        let view = HaloTimelineView(model: project, perform: { sent.commands.append($0) })
            .frame(width: size.width, height: size.height, alignment: .top)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(400))

        /// The point, in the strip's top-left space, of `frame` in lane `row`.
        func point(frame: Int, row: Int) -> CGPoint {
            let x = layout.labelColumn + layout.divider + Double(SuiteSpacing.s) + Double(frame) * frameWidth
            return CGPoint(x: x, y: layout.ruler + layout.lane * (Double(row) + 0.5))
        }

        try await click(point(frame: 30, row: floor), in: window, height: size.height)
        #expect(sent.commands.contains(.selectLayer(rows[floor].id)), "a click on Floor's bar sent \(sent.commands)")

        sent.commands = []
        try await click(point(frame: 24, row: ball), in: window, height: size.height)
        #expect(
            sent.commands.contains(.selectLaneKeys(layerID: rows[ball].id, frame: 24, extending: false)),
            "a click on Ball's diamond at 24 sent \(sent.commands)")
        #expect(!sent.commands.contains(.selectLayer(rows[floor].id)), "a click on Ball's lane selected Floor")
    }

    /// A mouse-down and mouse-up at `point`, measured from the window's top-left.
    private func click(_ point: CGPoint, in window: NSWindow, height: Double) async throws {
        let location = CGPoint(x: point.x, y: height - point.y)
        for kind in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(
                NSEvent.mouseEvent(
                    with: kind, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            window.sendEvent(event)
            try await Task.sleep(for: .milliseconds(50))
        }
        try await Task.sleep(for: .milliseconds(200))
    }
}

@MainActor private final class Sent {
    var commands: [HaloCommand] = []
}
