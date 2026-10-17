// KeyframeButtonTests.swift: each KeyState's symbol, color, VoiceOver value
// and key-here diamond, that the button keeps its width in every state, and
// that its two buttons read as two 28 pt elements with their own identifiers
// after the diamond appears (#1282; read from the window's accessibility
// tree, which SwiftUI builds once the app is asked for it), and that a
// disabled pair's tooltips say why it can't act. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@Test func eachKeyStateHasItsSymbolColorAndVoiceOverValue() {
    #expect(KeyState.idle.symbol == "stopwatch")
    #expect(KeyState.animated.symbol == "stopwatch.fill" && KeyState.keyedHere.symbol == "stopwatch.fill")
    #expect(KeyState.idle.color == SuiteColor.textSecondary)
    #expect(KeyState.animated.color == SuiteColor.stateKeyed && KeyState.keyedHere.color == SuiteColor.stateKeyed)
    #expect(KeyState.allCases.map(\.voiceOverValue) == ["Not animated", "Animated", "Keyed at this frame"])
}

@Test func theDiamondAddsOrRemovesTheKeyHere() {
    #expect(KeyState.idle.diamond == nil)
    #expect(KeyState.animated.diamond?.symbol == "diamond" && KeyState.animated.diamond?.action == "Add Key")
    #expect(KeyState.keyedHere.diamond?.symbol == "diamond.fill" && KeyState.keyedHere.diamond?.action == "Remove Key")
}

/// A pair that can act names its action; a disabled one shows the reason on both buttons, so a mouse user hovering
/// either one learns why it does nothing (no dead controls).
@Test func aDisabledPairTellsWhyOnBothButtons() {
    func help(_ state: KeyState, _ unavailable: String? = nil) -> [String?] {
        let h = KeyframeButton.help("X", state: state, unavailable: unavailable)
        return [h.stopwatch, h.diamond]
    }
    #expect(help(.idle) == ["Animate X", nil])
    #expect(help(.keyedHere) == ["Stop Animating X", "Remove Key for X"])
    let why = "Select a layer to animate it."
    #expect(help(.idle, why) == [why, nil])
    #expect(help(.animated, why) == [why, why])
}

/// The diamond slot is reserved even while empty, so the row never changes width.
@MainActor @Test func everyStateTakesTheSameRoom() {
    let sizes = KeyState.allCases.map { state in
        NSHostingView(rootView: KeyframeButton("Rotation", state: state, onToggle: {}, onKey: {})).fittingSize
    }
    #expect(sizes.allSatisfy { $0 == CGSize(width: 2 * SuiteSize.keyframeButton, height: SuiteSize.keyframeButton) })
}

/// Once the diamond appears, the stopwatch still reads 28 pt wide with its own
/// id, and the diamond has its own (#1282: both read the stopwatch's id and
/// the stopwatch 56 pt, over the diamond).
@MainActor @Test func eachPartReadsItsOwnIdAndFrameAfterTheDiamondAppears() {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let holder = KeyStateHolder()
    let host = NSHostingView(rootView: KeyframeButtonHost(holder: holder))
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = host
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    // Read the tree in each state: the 56 pt stopwatch only showed once its
    // element existed before the diamond did, as in the app.
    var buttons = [(id: String, frame: CGRect)]()
    for state in [KeyState.idle, .animated, .keyedHere] {
        holder.state = state
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        buttons = axButtons(in: window)
    }
    #expect(buttons.map(\.id) == ["k", "k.diamond"])
    #expect(buttons.allSatisfy { $0.frame.size == CGSize(width: SuiteSize.keyframeButton, height: SuiteSize.keyframeButton) })
}

@MainActor @Observable private final class KeyStateHolder {
    var state = KeyState.idle
}

private struct KeyframeButtonHost: View {
    let holder: KeyStateHolder
    var body: some View {
        KeyframeButton("Opacity", id: "k", state: holder.state, onToggle: {}, onKey: {}).padding(20)
    }
}

/// Every button under `element` in the accessibility tree, in tree order.
@MainActor private func axButtons(in element: Any) -> [(id: String, frame: CGRect)] {
    let node = element as AnyObject
    var found = [(id: String, frame: CGRect)]()
    if node.accessibilityRole?() == .button {
        found.append(((node.accessibilityIdentifier?() ?? nil) ?? "", node.accessibilityFrame?() ?? .zero))
    }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] { found += axButtons(in: child) }
    return found
}
