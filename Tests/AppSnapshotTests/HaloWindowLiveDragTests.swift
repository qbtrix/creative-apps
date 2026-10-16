// HaloWindowLiveDragTests.swift: what a drag costs the real Halo window. It
// hosts HaloWindow on `-HaloSample keyed` (24 fps, live services, paused) in
// a 1280 x 820 borderless window ordered in far off every screen, as
// HaloWindowPlaybackTests does, finds a control's frame in the accessibility
// tree (as LibraryLoupeGridButtonTests does) and sends it a mouse-down, 120
// dragged events at 120 Hz and a mouse-up, as PhotoWindowStrokeTests does.
// Spec, per drag: HaloWindow's body (a debug-only counter) runs at most 3
// times, the viewer's drawn layers redraw as it goes, and the drag lands as
// one undo step. While Ball's X is scrubbed between its keys (which adds a
// key), nothing else in the window moves, appears or goes until the release. Dragging Floor in the viewer
// lands where the Model's own begin/move/end puts it; scrubbing X in the
// inspector changes X. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor @Suite struct HaloWindowLiveDragTests {
    /// Floor spans the artboard's bottom band, so a press there hits it.
    static let floor = "comp-1-layer-1"

    @Test(.timeLimit(.minutes(3))) func aViewerDragRunsTheWindowAtMostThreeTimes() async throws {
        let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
        let hosted = try await HostedHaloWindow(project)
        defer { hosted.close() }
        let canvas = try #require(hosted.frame(of: "halo.viewer.canvas"), "no halo.viewer.canvas")
        // Composition (960, 980): the middle of Floor's band, under nothing else at frame 0.
        let start = CGPoint(x: canvas.midX, y: canvas.minY + canvas.height * (100.0 / 1080.0))
        let end = CGPoint(x: start.x + 120, y: start.y + 30)

        let drawn = Self.layerBodies()
        let (runs, after) = try await hosted.drag(from: start, to: end)
        let redrawn = Self.layerBodies().map { $0 - (drawn ?? 0) }

        var expected = project
        let artboard = (w: Double(canvas.width), h: Double(canvas.height))
        let from = try #require(expected.compositionPoint(
            x: start.x - canvas.minX, y: canvas.maxY - start.y, artboardWidth: artboard.w, artboardHeight: artboard.h))
        let to = try #require(expected.compositionPoint(
            x: end.x - canvas.minX, y: canvas.maxY - end.y, artboardWidth: artboard.w, artboardHeight: artboard.h))
        expected.beginViewerDrag(at: from)
        expected.moveViewerDrag(to: to)
        expected.endViewerDrag()
        let want = try #require(expected.viewerDrawList?.worldBox(of: Self.floor))
        let got = try #require(after.viewerDrawList?.worldBox(of: Self.floor))
        let report = "VIEWER-DRAG samples=120@120Hz | window bodies \(runs.map(String.init) ?? "n/a"), drawn layers \(redrawn.map(String.init) ?? "n/a"), undo \(after.undoTitle ?? "nil") selected \(after.selectedLayerID ?? "nil"), Floor at \(got.x),\(got.y) (want \(want.x),\(want.y))"
        print(report)

        if let runs { #expect(runs <= 3, "the window ran per drag sample: \(report)") }
        if let redrawn { #expect(redrawn >= 30, "the viewer didn't draw the drag as it went: \(report)") }
        #expect(after.history.undo.count == project.history.undo.count + 1, "the drag isn't one step: \(report)")
        #expect(after.undoTitle == "Undo Move", "\(report)")
        #expect(abs(got.x - want.x) < 0.5 && abs(got.y - want.y) < 0.5, "the drag landed elsewhere: \(report)")
        #expect(after.viewerDrag == nil, "\(report)")
    }

    @Test(.timeLimit(.minutes(3))) func anInspectorScrubMovesNothingElseInTheWindow() async throws {
        var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
        // Ball's X is keyed at 0 and 24, so scrubbing it at frame 6 adds a key.
        project.selectLayer("comp-1-layer-2")
        project.scrub(to: 6)
        let hosted = try await HostedHaloWindow(project)
        defer { hosted.close() }
        let before = hosted.frames(under: "halo.")
        let row = try #require(before["halo.inspector.row.x"], "no halo.inspector.row.x")
        let start = CGPoint(x: row.midX, y: row.midY)
        var moved: Set<String> = []
        let (_, after) = try await hosted.drag(from: start, to: CGPoint(x: start.x + 120, y: start.y), every: 20) {
            let now = hosted.frames(under: "halo.")
            // The dragged bar draws its focus ring; everything else holds still.
            for id in Set(before.keys).union(now.keys) where id != "halo.inspector.row.x" && now[id] != before[id] {
                moved.insert("\(id) \(before[id].map { "\($0)" } ?? "new") -> \(now[id].map { "\($0)" } ?? "gone")")
            }
        }
        let report = "WINDOW-LAYOUT \(before.count) elements | moved or came and went during the scrub: \(moved.isEmpty ? "none" : moved.sorted().joined(separator: "; "))"
        print(report)
        #expect(before.count >= 16, "the window's elements weren't found: \(before.keys.sorted())")
        #expect(moved.isEmpty, "the window's layout changed during a scrub: \(report)")
        #expect(after.undoTitle == "Undo Change Position X", "\(report)")
    }

    /// HaloLiveLayers' body runs so far; nil in release, which has no counter.
    static func layerBodies() -> Int? {
        #if DEBUG
        return HaloLiveLayers.bodyRuns
        #else
        return nil
        #endif
    }

    @Test(.timeLimit(.minutes(3))) func anInspectorScrubRunsTheWindowAtMostThreeTimes() async throws {
        var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
        project.selectLayer(Self.floor)
        let x = try #require(project.propertyRows.first { $0.property == .x }?.value)
        let hosted = try await HostedHaloWindow(project)
        defer { hosted.close() }
        let row = try #require(hosted.frame(of: "halo.inspector.row.x"), "no halo.inspector.row.x")
        let start = CGPoint(x: row.midX, y: row.midY)

        let drawn = Self.layerBodies()
        let (runs, after) = try await hosted.drag(from: start, to: CGPoint(x: start.x + 120, y: start.y))
        let redrawn = Self.layerBodies().map { $0 - (drawn ?? 0) }

        let moved = after.propertyRows.first { $0.property == .x }?.value
        let report = "INSPECTOR-SCRUB samples=120@120Hz | window bodies \(runs.map(String.init) ?? "n/a"), drawn layers \(redrawn.map(String.init) ?? "n/a"), undo \(after.undoTitle ?? "nil"), X \(x) -> \(moved.map { "\($0)" } ?? "nil")"
        print(report)

        if let runs { #expect(runs <= 3, "the window ran per scrub sample: \(report)") }
        if let redrawn { #expect(redrawn >= 30, "the viewer didn't draw the scrub as it went: \(report)") }
        #expect(after.history.undo.count == project.history.undo.count + 1, "the scrub isn't one step: \(report)")
        #expect(after.undoTitle == "Undo Change Position X", "\(report)")
        #expect(moved != nil && moved != x, "the scrub didn't change X: \(report)")
    }
}

/// HaloWindow on `project`, hosted far off every screen with accessibility on.
@MainActor final class HostedHaloWindow {
    let window: NSWindow
    let host: CountingHostingView<AnyView>

    init(_ project: HaloProject) async throws {
        let app = NSApplication.shared
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        // The test can't make its app active over whatever the person at the
        // Mac is using, so every press here is an activation click; the
        // viewer takes those too, as it does in a key window.
        host = CountingHostingView(rootView: AnyView(
            HaloWindow(model: project).environment(\.haloViewerTakesActivationClicks, true)))
        let frame = CGRect(x: 0, y: 0, width: 1280, height: 820)
        host.frame = frame
        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        // The viewer's gestures map points only once they know the artboard's size.
        try await Task.sleep(for: .milliseconds(500))
    }

    func close() { window.close() }

    /// Every identified accessibility node under `prefix` and its frame in
    /// window coordinates (the first, where two share an identifier).
    func frames(under prefix: String) -> [String: CGRect] {
        var found: [String: CGRect] = [:]
        for node in Self.nodes(in: host) {
            guard let id = node.accessibilityIdentifier?() ?? nil, id.hasPrefix(prefix), found[id] == nil,
                let screen = node.accessibilityFrame?()
            else { continue }
            found[id] = window.convertFromScreen(screen)
        }
        return found
    }

    /// The frame, in window coordinates, of the accessibility node `identifier`.
    func frame(of identifier: String) -> CGRect? {
        guard let node = Self.nodes(in: host).first(where: { ($0.accessibilityIdentifier?() ?? nil) == identifier }),
            let screen = node.accessibilityFrame?()
        else { return nil }
        return window.convertFromScreen(screen)
    }

    /// A press at `from`, 120 dragged events at 120 Hz on the line to `to`,
    /// and the release there: the window's body runs over it (nil in release)
    /// and the project it shows after.
    func drag(
        from: CGPoint, to: CGPoint, every: Int = 0, during: () -> Void = {}
    ) async throws -> (runs: Int?, after: HaloProject) {
        try await Task.sleep(for: .milliseconds(200))
        let before = Self.bodies()
        send(.leftMouseDown, at: from)
        let clock = ContinuousClock()
        let began = clock.now
        for i in 1...120 {
            try await Task.sleep(until: began + .microseconds(8_333 * i), clock: clock)
            let t = Double(i) / 120
            send(.leftMouseDragged, at: CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
            if every > 0, i % every == 0 {
                try await Task.sleep(for: .milliseconds(30))
                during()
            }
        }
        send(.leftMouseUp, at: to)
        try await Task.sleep(for: .milliseconds(300))
        let runs = Self.bodies().map { $0 - (before ?? 0) }
        #if DEBUG
        let after = try #require(HaloWindow.shownProject)
        #else
        let after = HaloProject()
        #endif
        return (runs, after)
    }

    private func send(_ kind: NSEvent.EventType, at point: CGPoint) {
        guard let event = NSEvent.mouseEvent(
            with: kind, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
        else {
            Issue.record("no \(kind) event")
            return
        }
        window.sendEvent(event)
    }

    private static func bodies() -> Int? {
        #if DEBUG
        return HaloWindow.bodyRuns
        #else
        return nil
        #endif
    }

    /// Every node under `element` in the accessibility tree, in tree order.
    private static func nodes(in element: Any) -> [AnyObject] {
        let node = element as AnyObject
        return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { nodes(in: $0) }
    }
}
#endif
