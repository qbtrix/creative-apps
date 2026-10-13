// KeyframeButtonTests.swift: each KeyState's symbol, color, VoiceOver value
// and key-here diamond, and that the button keeps its width in every state.
// macOS only.
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

/// The diamond slot is reserved even while empty, so the row never changes width.
@MainActor @Test func everyStateTakesTheSameRoom() {
    let sizes = KeyState.allCases.map { state in
        NSHostingView(rootView: KeyframeButton("Rotation", state: state, onToggle: {}, onKey: {})).fittingSize
    }
    #expect(sizes.allSatisfy { $0 == CGSize(width: 2 * SuiteSize.keyframeButton, height: SuiteSize.keyframeButton) })
}
