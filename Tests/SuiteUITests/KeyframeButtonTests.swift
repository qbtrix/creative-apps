// KeyframeButtonTests.swift: each KeyState's symbol, color, VoiceOver value
// and key-here diamond, that the button keeps its width in every state, and
// that its two buttons read as two 28 pt elements with their own identifiers
// after the diamond appears (#1282; read from the window's accessibility
// tree, which SwiftUI builds once the app is asked for it), that a
// disabled pair's tooltips say why it can't act, that SuiteKeyframeFacing
// gives each presence's stopwatch, diamond, action and spoken text (equal to
// the contract's Fake), and that each `suite.controls` entry's reason is its
// tooltip. macOS only.
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

@Test func faceForEachPresenceGivesItsStopwatchDiamondActionAndSpokenText() {
    let facing = SuiteKeyframeFacing()
    #expect(facing.face(for: .idle) == KeyframeFace(
        symbol: "stopwatch", diamondSymbol: nil, diamondAction: nil, spoken: "Not animated"))
    #expect(facing.face(for: .animated) == KeyframeFace(
        symbol: "stopwatch.fill", diamondSymbol: "diamond", diamondAction: .add, spoken: "Animated"))
    #expect(facing.face(for: .keyedHere) == KeyframeFace(
        symbol: "stopwatch.fill", diamondSymbol: "diamond.fill", diamondAction: .remove, spoken: "Keyed at this frame"))
    for presence in KeyPresence.allCases {
        #expect(facing.face(for: presence) == FakeKeyframeFacing().face(for: presence))
    }
    #expect(KeyState.allCases.map(\.presence) == KeyPresence.allCases)
    #expect(KeyAction.add.title == "Add Key" && KeyAction.remove.title == "Remove Key")
}

/// Each entry the pair lists in `suite.controls` takes its button's tooltip as
/// the reason while it can't act, and none while it can.
@Test func eachEntrysReasonEqualsItsHelp() {
    let why = "Select a layer to animate it."
    for state in KeyState.allCases {
        let help = KeyframeButton.help("X", state: state, unavailable: why)
        let off = KeyframeButton.entries("X", id: "k", state: state, enabled: false, unavailable: why)
        #expect(off.stopwatch == ControlEntry(id: "k", enabled: false, reason: help.stopwatch))
        #expect(off.diamond?.reason == help.diamond)
        #expect(off.diamond?.id == (state.diamond == nil ? nil : KeyframeButton.diamondID("k")))
        let on = KeyframeButton.entries("X", id: "k", state: state, enabled: true)
        #expect(on.stopwatch == ControlEntry(id: "k", enabled: true) && on.diamond?.reason == nil)
    }
    let bare = KeyframeButton.entries("X", id: "k", state: .animated, enabled: false)
    #expect(bare.stopwatch.reason == "Stop Animating X" && bare.diamond?.reason == "Add Key for X")
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
    let sizes = KeyState.allCases.flatMap { state in
        [
            NSHostingView(rootView: KeyframeButton("Rotation", state: state, onToggle: {}, onKey: {})).fittingSize,
            NSHostingView(rootView: KeyframeButton(
                "Rotation", id: "k", state: state, facing: FakeKeyframeFacing(), registers: true,
                onToggle: {}, onKey: {}).environment(\.suiteReduceMotion, true)).fittingSize,
        ]
    }
    #expect(sizes.count == 6)
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
@MainActor func axButtons(in element: Any) -> [(id: String, frame: CGRect)] {
    let node = element as AnyObject
    var found = [(id: String, frame: CGRect)]()
    if node.accessibilityRole?() == .button {
        found.append(((node.accessibilityIdentifier?() ?? nil) ?? "", node.accessibilityFrame?() ?? .zero))
    }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] { found += axButtons(in: child) }
    return found
}
