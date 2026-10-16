// PhotoWindowStrokeTests.swift: what a brush stroke costs the real Photo
// window. It hosts PhotoWindow itself (State, renderer, pacer, every panel and
// area modifier) on the `large` fixture, brush 64 px, in a 1280 x 820
// borderless window ordered in far off every screen (never shown, never key,
// but it gets AppKit's display cycle and mouse events), and sends it a
// mouse-down, 120 dragged events at 120 Hz and a mouse-up, so CanvasViewport's
// drag gesture reaches PhotoWindow.perform as a hand's would. Spec, during the
// stroke: the tile layers show it, PhotoEditor's body runs at most once
// (a debug-only counter) and no large layer is drawn on the CPU (CALayer
// `display`, swizzled for the process); after it, the window's workspace holds
// the stroke. NSHostingView's layout passes are reported, not judged: SwiftUI
// runs one per mouse event for the gesture, cheap when no body changed.
// PHOTO_WINDOW_STROKE_SECONDS=20 first strokes for that long, for `sample`.
import AppKit
import ObjectiveC
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoWindowStrokeTests {
    @Test(.timeLimit(.minutes(2))) func aBrushStrokeRedrawsOnlyTheCanvas() async throws {
        var open = try PhotoWorkspace.fixture(.large)
        open.selectTool(.brush)
        open.setToolOption(.size(64))
        let host = CountingHostingView(rootView: PhotoWindow(model: open))
        let frame = CGRect(x: 0, y: 0, width: 1280, height: 820)
        host.frame = frame
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        defer { window.close() }

        // The first picture: every tile layer has its image (seconds in debug).
        let canvas = try #require(await first(TileCanvasView.self, in: host))
        for _ in 0..<600 where tileImages(canvas).isEmpty { try await Task.sleep(for: .milliseconds(50)) }
        let shown = tileImages(canvas)
        try #require(!shown.isEmpty, "the canvas never showed its first picture")
        try await Task.sleep(for: .milliseconds(300))
        let edited = try #require(await first(PhotoWindowEditedView.self, in: host))
        let before = try #require(edited.workspace)

        let box = canvas.convert(canvas.bounds, to: nil)
        let seconds = Double(ProcessInfo.processInfo.environment["PHOTO_WINDOW_STROKE_SECONDS"] ?? "") ?? 0
        let clock = ContinuousClock()
        let until = clock.now + .seconds(seconds)
        var row = 0
        while clock.now < until {
            row += 1
            let y = box.minY + 40 + Double(row * 23 % Int(max(box.height - 80, 1)))
            try await stroke(from: CGPoint(x: box.minX + box.width * 0.25, y: y), in: window)
            send(.leftMouseUp, at: CGPoint(x: box.minX + box.width * 0.25 + 360, y: y), to: window)
        }
        // The last of those strokes lands its panels before the measured one starts.
        if seconds > 0 { try await Task.sleep(for: .milliseconds(500)) }
        let start = CGPoint(x: box.minX + box.width * 0.25, y: box.midY)
        let layouts = host.layouts
        let layoutTime = host.layoutTime
        let bodies = editorBodies()
        LayerDisplays.start(in: host)
        try await stroke(from: start, in: window)
        // Let the stroke's last renders land before the mouse comes up.
        try await Task.sleep(for: .milliseconds(150))
        let passes = host.layouts - layouts
        let passTime = host.layoutTime - layoutTime
        let editorRuns = editorBodies().map { $0 - (bodies ?? 0) }
        let drawn = LayerDisplays.stop()
        let inked = Set(tileImages(canvas)).subtracting(shown).count
        send(.leftMouseUp, at: CGPoint(x: start.x + 360, y: start.y), to: window)
        for _ in 0..<100 where edited.workspace?.isDirty != true { try await Task.sleep(for: .milliseconds(20)) }
        let after = try #require(edited.workspace)

        let big = drawn.filter { $0.area >= 256 * 256 }
        let kinds = Dictionary(grouping: drawn, by: \.name).map { "\($1.count)x \($0)" }.sorted()
        let report = [
            "WINDOW-STROKE config=\(PhotoBrushLatencyTests.config) canvas=4000x3000 window=1280x820",
            "samples=120@120Hz | during the stroke: editor bodies \(editorRuns.map(String.init) ?? "n/a"),",
            "SwiftUI passes \(passes) (\(String(format: "%.1f", passTime)) ms), CPU layer displays \(drawn.count)",
            "(\(kinds.joined(separator: ", "))) | tile layers inked \(inked) | after: dirty \(after.isDirty),",
            "revision \(before.revision) -> \(after.revision)",
        ].joined(separator: " ")
        print(report)

        #expect(inked > 0, "the canvas showed nothing while drawing: \(report)")
        if let editorRuns { #expect(editorRuns <= 1, "the editor ran again during the stroke: \(report)") }
        #expect(big.isEmpty, "a large layer was drawn on the CPU during the stroke: \(report)")
        #expect(after.isDirty && after.revision > before.revision, "the window never took the stroke: \(report)")
    }

    /// PhotoEditor's body runs so far; nil in release, which has no counter.
    private func editorBodies() -> Int? {
        #if DEBUG
        return PhotoEditor.bodyRuns
        #else
        return nil
        #endif
    }

    /// A mouse-down at `start`, then 120 dragged events at 120 Hz, 3 px apart on a wave.
    private func stroke(from start: CGPoint, in window: NSWindow) async throws {
        send(.leftMouseDown, at: start, to: window)
        let clock = ContinuousClock()
        let began = clock.now
        for i in 1...120 {
            try await Task.sleep(until: began + .microseconds(8_333 * i), clock: clock)
            send(.leftMouseDragged, at: CGPoint(x: start.x + 3 * Double(i), y: start.y + 40 * sin(Double(i) / 12)), to: window)
        }
    }

    private func send(_ kind: NSEvent.EventType, at point: CGPoint, to window: NSWindow) {
        guard let event = NSEvent.mouseEvent(
            with: kind, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
        else {
            Issue.record("no \(kind) event")
            return
        }
        window.sendEvent(event)
    }

    /// The images the tile layers show now.
    private func tileImages(_ canvas: TileCanvasView) -> [ObjectIdentifier] {
        (canvas.layer?.sublayers?.first?.sublayers ?? []).compactMap {
            ($0.contents as AnyObject?).map(ObjectIdentifier.init)
        }
    }

    /// The first `V` in `view`'s tree, waiting up to two seconds for SwiftUI to make it.
    private func first<V: NSView>(_ type: V.Type, in view: NSView) async -> V? {
        for _ in 0..<100 {
            if let found = find(type, in: view) { return found }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return nil
    }

    private func find<V: NSView>(_ type: V.Type, in view: NSView) -> V? {
        if let match = view as? V { return match }
        return view.subviews.lazy.compactMap { find(type, in: $0) }.first
    }
}

/// An NSHostingView that counts its layout passes: one per SwiftUI update of the window.
final class CountingHostingView<Content: View>: NSHostingView<Content> {
    private(set) var layouts = 0
    /// Milliseconds spent in all the layout passes.
    private(set) var layoutTime = 0.0

    override func layout() {
        layouts += 1
        let clock = ContinuousClock()
        let began = clock.now
        super.layout()
        layoutTime += Double((clock.now - began) / .microseconds(1)) / 1000
    }
}

/// The CPU-drawn layer displays in one view's layer tree while recording.
/// CALayer's `display` is swapped once per process for one that logs and then
/// draws as before; layers of other windows (other suites) aren't logged.
/// Only the main thread touches the log.
enum LayerDisplays {
    struct Display {
        let name: String
        let area: Double
    }

    nonisolated(unsafe) private static var root: CALayer?
    nonisolated(unsafe) private static var log: [Display] = []
    private static let installed: Bool = {
        guard let original = class_getInstanceMethod(CALayer.self, #selector(CALayer.display)),
            let logging = class_getInstanceMethod(CALayer.self, #selector(CALayer.photoTestLoggedDisplay))
        else { return false }
        method_exchangeImplementations(original, logging)
        return true
    }()

    @MainActor static func start(in view: NSView) {
        #expect(installed, "CALayer.display couldn't be swapped")
        (root, log) = (view.layer, [])
    }

    @MainActor static func stop() -> [Display] {
        root = nil
        return log
    }

    static func note(_ layer: CALayer) {
        guard let root else { return }
        var up: CALayer? = layer
        while let current = up, current !== root { up = current.superlayer }
        guard up != nil else { return }
        let size = layer.bounds.size
        log.append(Display(name: "\(type(of: layer)) \(Int(size.width))x\(Int(size.height))", area: size.width * size.height))
    }
}

extension CALayer {
    /// After the swap this runs for `display`, and the call inside runs the original.
    /// The window's layers display on the main thread; others go unlogged.
    @objc func photoTestLoggedDisplay() {
        if Thread.isMainThread { LayerDisplays.note(self) }
        photoTestLoggedDisplay()
    }
}
