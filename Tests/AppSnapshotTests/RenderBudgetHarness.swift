// RenderBudgetHarness.swift: the real-window render budget harness, the feel
// gate's shared host (Tests/render-budgets.md has the budgets and targets).
// RenderBudgetWindow hosts an app's real window view on a fixture in a
// CountingHostingView inside a 1280 x 820 borderless window ordered in far
// off every screen: never shown, but it gets AppKit's display cycle and mouse
// events. Accessibility is turned on first, so elements are found by
// identifier and every run builds the same tree (the cost an accessibility
// client adds is part of what it measures).
//
// It drives scripted steps, each paced at 120 Hz and timed on its own clock as
// the event's work plus the layout and display it forced: a mouse drag of N
// samples, clicks, a split-divider drag, a scroll, N increments of an
// adjustable element and N ticks of any closure (a fake refresh link).
// `measure` turns one interaction into a RenderStep: the window body's runs
// (a debug-only `bodyRuns` counter the caller reads), the root hosting view's
// layout passes and time, and the per-step p50 / p95 (FrameProbe's nearest
// rank). `expectBodies` gates a body count; `expectP95` judges time and
// belongs only in tests Tests/perf-suites.txt lists.
//
// What a test process can't drive: it is never the active app, so every press
// is a window-activation click, which a SwiftUI gesture ignores unless it opts
// in (`allowsWindowActivationEvents`); SwiftUI's own canvases and AppKit
// controls take them, inspector scrub rows and Halo's viewer don't yet. Keys
// need a key window, which it can't have either. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

/// What one scripted interaction cost the window.
struct RenderStep: CustomStringConvertible {
    let name: String
    /// Events or ticks sent.
    let steps: Int
    /// The window body's runs during the interaction; nil in release, which has no counter.
    let bodies: Int?
    /// NSHostingView layout passes and the milliseconds spent in them.
    let layouts: Int
    let layoutMilliseconds: Double
    /// Per-step main-thread milliseconds: sendEvent plus the layout and display it forced.
    let p50: Double
    let p95: Double

    var description: String {
        "RENDER-BUDGET \(name): steps \(steps) | window bodies \(bodies.map(String.init) ?? "n/a") | layout passes "
            + "\(layouts) (\(String(format: "%.1f", layoutMilliseconds)) ms) | step p50 \(String(format: "%.2f", p50)) ms "
            + "p95 \(String(format: "%.2f", p95)) ms"
    }
}

/// An app's real window hosted off screen, driven by scripted events.
@MainActor final class RenderBudgetWindow<Content: View> {
    let host: CountingHostingView<Content>
    let window: NSWindow
    /// Wall milliseconds of each step in the interaction being measured.
    private var stepTimes: [Double] = []

    init(_ view: Content, size: CGSize = CGSize(width: 1280, height: 820)) {
        // The accessibility tree, which `element` and `label` read, is built only for a client that asks;
        // turned on before the window exists so every run builds it the same way.
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        host = CountingHostingView(rootView: view)
        let frame = CGRect(origin: .zero, size: size)
        host.frame = frame
        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
    }

    func close() { window.close() }

    /// Lets SwiftUI settle: `milliseconds` of run-loop turns.
    func settle(_ milliseconds: Int = 300) async throws { try await Task.sleep(for: .milliseconds(milliseconds)) }

    /// Runs `interaction` and reports what it cost; `bodies` reads the window's body counter.
    func measure(
        _ name: String, bodies: () -> Int?, _ interaction: () async throws -> Void
    ) async throws -> RenderStep {
        let before = bodies()
        let layouts = host.layouts
        let layoutTime = host.layoutTime
        stepTimes = []
        try await interaction()
        try await settle(100)
        let times = stepTimes.sorted()
        let step = RenderStep(
            name: name, steps: times.count, bodies: bodies().map { $0 - (before ?? 0) },
            layouts: host.layouts - layouts, layoutMilliseconds: host.layoutTime - layoutTime,
            p50: SuiteFrameProbe.nearestRank(times, 0.5) ?? 0, p95: SuiteFrameProbe.nearestRank(times, 0.95) ?? 0)
        print(step)
        return step
    }

    // MARK: Steps

    /// One timed step: `action`, then the layout and display it forced.
    func timed(_ action: () -> Void) {
        let clock = ContinuousClock()
        let began = clock.now
        action()
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        stepTimes.append(Double((clock.now - began) / .microseconds(1)) / 1000)
    }

    /// `count` calls of `tick(i)`, one per real 1/120 s, each a timed step.
    func ticks(_ count: Int, _ tick: (Int) -> Void) async throws {
        let clock = ContinuousClock()
        let began = clock.now
        for i in 1...count {
            try await Task.sleep(until: began + .microseconds(8_333 * i), clock: clock)
            timed { tick(i) }
        }
    }

    /// A mouse-down at `start`, `samples` dragged events at 120 Hz along `path(i)` (window points), and a mouse-up
    /// unless `release` is false.
    func drag(from start: CGPoint, samples: Int = 120, release: Bool = true, path: (Int) -> CGPoint) async throws {
        timed { send(.leftMouseDown, at: start) }
        try await ticks(samples) { send(.leftMouseDragged, at: path($0)) }
        if release { timed { send(.leftMouseUp, at: path(samples)) } }
    }

    /// A straight drag from `start` by `offset` over `samples` events.
    func drag(from start: CGPoint, by offset: CGVector, samples: Int = 120) async throws {
        try await drag(from: start, samples: samples) {
            let t = Double($0) / Double(samples)
            return CGPoint(x: start.x + offset.dx * t, y: start.y + offset.dy * t)
        }
    }

    /// A click at `point` (window coordinates). Not a timed step by itself: run it in `ticks`.
    func click(at point: CGPoint) {
        send(.leftMouseDown, at: point)
        send(.leftMouseUp, at: point)
    }

    /// Scrolls `scrollView` down by `dy` points per step over `samples` steps at 120 Hz; returns the clip
    /// view's origin before and after. A wheel event made in a test has no window or phase and a SwiftUI
    /// scroll view ignores it, so each step moves the clip view as a wheel tick does (`scroll(to:)` and
    /// `reflectScrolledClipView`), then the layout and display it forces: the lazy grid's cost is the same.
    func scroll(_ scrollView: NSScrollView, by dy: CGFloat, samples: Int = 120) async throws -> (before: CGFloat, after: CGFloat) {
        let clip = scrollView.contentView
        let before = clip.bounds.origin.y
        let lowest = max((scrollView.documentView?.frame.height ?? 0) - clip.bounds.height, 0)
        try await ticks(samples) { i in
            let y = min(max(before + dy * Double(i), 0), lowest)
            clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
            scrollView.reflectScrolledClipView(clip)
        }
        return (before, clip.bounds.origin.y)
    }

    /// Runs the accessibility action called `name` on the element called `identifier` (a custom action
    /// such as a grid cell's "Open"); false when there is no such element or action.
    @discardableResult func perform(_ name: String, on identifier: String) -> Bool {
        guard let node = Self.node(identifier, in: host),
            let action = ((node.accessibilityCustomActions?() ?? nil) ?? []).first(where: { $0.name == name })
        else { return false }
        if let handler = action.handler { return handler() }
        guard let target = action.target as? NSObject, let selector = action.selector else { return false }
        target.perform(selector, with: action)
        return true
    }

    /// The innermost scroll view under `point` (window coordinates).
    func scrollView(at point: CGPoint) -> NSScrollView? {
        var found: NSScrollView?
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView, scroll.convert(scroll.bounds, to: nil).contains(point) { found = scroll }
            view.subviews.forEach(walk)
        }
        walk(host)
        return found
    }

    /// A mouse event at `point` (window coordinates), sent through the window as AppKit sends a hand's.
    func send(_ kind: NSEvent.EventType, at point: CGPoint) {
        guard let event = NSEvent.mouseEvent(
            with: kind, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
        else { Issue.record("no \(kind) event"); return }
        window.sendEvent(event)
    }

    // MARK: Finding things

    /// The first `V` in the window's view tree, waiting up to two seconds for SwiftUI to make it.
    func first<V: NSView>(_ type: V.Type) async -> V? {
        for _ in 0..<100 {
            if let found = Self.find(type, in: host) { return found }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return nil
    }

    static func find<V: NSView>(_ type: V.Type, in view: NSView) -> V? {
        if let match = view as? V { return match }
        return view.subviews.lazy.compactMap { find(type, in: $0) }.first
    }

    /// The window-coordinate frame of the accessibility element called `identifier`, waiting up to two seconds.
    func element(_ identifier: String) async -> CGRect? {
        for _ in 0..<100 {
            if let screen = Self.frame(of: identifier, in: host) {
                return window.convertFromScreen(screen)
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return nil
    }

    /// The window point of `point` on an artboard `size` big drawn in `box` (window coordinates, so y up),
    /// `point` measured from the artboard's top left in its own units.
    func point(_ point: CGPoint, on size: CGSize, in box: CGRect) -> CGPoint {
        CGPoint(x: box.minX + point.x * box.width / size.width, y: box.maxY - point.y * box.height / size.height)
    }

    /// Every accessibility identifier in the window now, in tree order (for writing a scenario).
    func identifiers() -> [String] {
        var ids: [String] = []
        func walk(_ element: Any, _ depth: Int) {
            let node = element as AnyObject
            if let id = node.accessibilityIdentifier?() ?? nil, !id.isEmpty { ids.append(id) }
            guard depth < 60 else { return }
            for child in (node.accessibilityChildren?() ?? nil) ?? [] { walk(child, depth + 1) }
        }
        walk(host, 0)
        return ids
    }

    /// `count` increments of the adjustable element called `identifier` (a slider, a scrub row), one per
    /// real 1/120 s, the way VoiceOver and XCUI adjust it; false when there is no such element.
    @discardableResult func adjust(_ identifier: String, steps count: Int) async throws -> Bool {
        guard let node = Self.node(identifier, in: host) else { return false }
        try await ticks(count) { _ in _ = node.accessibilityPerformIncrement?() }
        return true
    }

    private static func frame(of identifier: String, in host: NSView) -> CGRect? {
        node(identifier, in: host)?.accessibilityFrame?()
    }

    /// The first node called `identifier` under `element` in the accessibility tree, in tree order.
    /// SwiftUI's nodes answer the NSAccessibility methods informally, so they are read as AnyObject.
    private static func node(_ identifier: String, in element: Any, depth: Int = 0) -> AnyObject? {
        let node = element as AnyObject
        if (node.accessibilityIdentifier?() ?? nil) == identifier { return node }
        guard depth < 60 else { return nil }
        for child in (node.accessibilityChildren?() ?? nil) ?? [] {
            if let found = Self.node(identifier, in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    /// The split views SwiftUI's columns use, outermost first: the sidebar's, then the inspector's.
    func splitViews() async -> [NSSplitView] {
        _ = await first(NSSplitView.self)
        var found: [NSSplitView] = []
        func walk(_ view: NSView) {
            if let split = view as? NSSplitView { found.append(split) }
            view.subviews.forEach(walk)
        }
        walk(host)
        return found
    }

    /// Drags `split`'s divider `index` by `offset` points over `samples` steps at 120 Hz; returns the
    /// pane after the divider's width before and after. NSSplitView tracks a divider drag in a modal loop
    /// inside mouseDown that pulls events from the app queue, which a test can't pace sample by sample,
    /// so each step moves the divider the way that loop does: setPosition(_:ofDividerAt:), through the
    /// split view's delegate constraints, then the layout and display it forces.
    func dragDivider(
        _ index: Int, of split: NSSplitView, by offset: CGFloat, samples: Int = 120
    ) async throws -> (before: CGFloat, after: CGFloat) {
        let panes = split.arrangedSubviews
        guard index + 1 < panes.count else {
            Issue.record("the split view has no divider \(index)")
            return (0, 0)
        }
        let size = { split.isVertical ? panes[index + 1].frame.width : panes[index + 1].frame.height }
        let start = split.isVertical ? panes[index + 1].frame.minX : panes[index + 1].frame.minY
        let before = size()
        try await ticks(samples) { i in
            split.setPosition(start - split.dividerThickness + offset * Double(i) / Double(samples), ofDividerAt: index)
        }
        return (before, size())
    }
}

/// Fails when `step` ran the window body more than `budget` times; `target` is where it should get to.
func expectBodies(
    _ step: RenderStep, atMost budget: Int, target: Int, sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let bodies = step.bodies else { return }
    #expect(bodies <= budget, "\(step) (budget \(budget), target \(target))", sourceLocation: sourceLocation)
}

/// Fails when `step`'s p95 step time is over `budget` ms; `target` is where it should get to.
func expectP95(
    _ step: RenderStep, atMost budget: Double, target: Double, sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(step.p95 <= budget, "\(step) (budget \(budget) ms, target \(target) ms)", sourceLocation: sourceLocation)
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
