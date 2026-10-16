// ScrubAccessibilityTests.swift: the bar slider's accessibility element, read
// from the window's accessibility tree (which SwiftUI builds once the app is
// asked for it). It is a slider named by its label, so VoiceOver and XCUI's
// `sliders[label]` find it, its value is spoken with the unit, and increment
// and decrement step it by one step through onChange and onEnd. Building that
// element costs the same whatever the range: a slider over -100,000...100,000
// at step 1 (Halo's X) renders as fast as one over 0...1, where a stepped
// Slider used to make one tick per step on every body pass. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@MainActor @Test func theBarIsAnAdjustableSliderWithItsLabelAndSpokenValue() throws {
    let log = AdjustLog()
    let window = axWindow(InspectorSliderRow(
        "Rotation", value: 45, in: -180...180, step: 1, unit: "°", decimals: 0,
        onChange: { log.values.append($0) }, onEnd: { log.ends += 1 }))
    defer { window.orderOut(nil) }
    let slider = try #require(axElement(in: window, role: .slider), "the bar is no slider")
    let node = slider as AnyObject
    #expect(node.accessibilityLabel?() == "Rotation")
    #expect(slider.value(forKey: "accessibilityValueDescription") as? String == "45 degrees")
    #expect(node.accessibilityPerformIncrement?() == true)
    #expect(node.accessibilityPerformDecrement?() == true)
    #expect(log.values == [46, 44] && log.ends == 2)
}

/// 40 rows re-rendered 10 times over Halo's X range cost about what they cost
/// over 0...1: the accessibility slider's work doesn't grow with range / step.
/// A ratio between two runs on the same machine, not a wall-clock budget, so
/// it stays in the gate (a stepped Slider made it about 300 times slower).
@MainActor @Test func aWideRangeRendersAsFastAsANarrowOne() {
    func seconds(_ range: ClosedRange<Double>, step: Double) -> Double {
        let holder = RowsHolder()
        let window = axWindow(Rows(holder: holder, range: range, step: step))
        defer { window.orderOut(nil) }
        let start = Date()
        for pass in 1...10 {
            holder.value = range.lowerBound + step * Double(pass)
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }
        return Date().timeIntervalSince(start)
    }
    _ = seconds(0...1, step: 0.01)  // warm up
    let narrow = seconds(0...1, step: 0.01)
    let wide = seconds(-100_000...100_000, step: 1)
    #expect(wide < narrow * 3 + 0.1, "wide \(wide) s, narrow \(narrow) s")
}

@MainActor private final class AdjustLog {
    var values: [Double] = []
    var ends = 0
}

@MainActor @Observable private final class RowsHolder {
    var value = 0.0
}

private struct Rows: View {
    let holder: RowsHolder
    let range: ClosedRange<Double>
    let step: Double
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<40, id: \.self) { row in
                InspectorSliderRow("Row \(row)", value: holder.value, in: range, step: step) { _ in }
            }
        }
        .frame(width: SuiteSize.editorPanelWidth)
    }
}

/// `view` in a window on screen, with the app's accessibility tree on.
@MainActor private func axWindow(_ view: some View) -> NSWindow {
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 320, height: 1200), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: view)
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    return window
}

/// The first element under `element` with `role`, in tree order.
@MainActor private func axElement(in element: Any, role: NSAccessibility.Role) -> NSObject? {
    let node = element as AnyObject
    if node.accessibilityRole?() == role { return node as? NSObject }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] {
        if let found = axElement(in: child, role: role) { return found }
    }
    return nil
}
