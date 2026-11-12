// ScrubKeyMonitorTests.swift: which key-downs a focused ScrubField takes ahead
// of the menu bar (ScrubKeyMonitor). Flare's J7 lost → to Animate > Next Frame,
// a bare → menu item, so the Rotation bar never stepped. macOS only.
import AppKit
@testable import SuiteUI
import Testing

@MainActor @Suite struct ScrubKeyMonitorTests {
    private func press(_ special: NSEvent.SpecialKey?, _ characters: String? = nil, _ flags: NSEvent.ModifierFlags = [])
        -> ScrubKeyMonitor.Press?
    {
        ScrubKeyMonitor.press(for: special, characters: characters, flags: flags)
    }

    /// →, ←, Home, End and Space, which Flare's menu binds bare, are the field's; so are ↑ and ↓.
    @Test func theFieldTakesItsKeysBareAndWithShiftOrOption() {
        #expect(press(.rightArrow, nil, [.function, .numericPad]) == .step(.increment, shift: false, option: false))
        #expect(press(.leftArrow) == .step(.decrement, shift: false, option: false))
        #expect(press(.upArrow, nil, .shift) == .step(.increment, shift: true, option: false))
        #expect(press(.rightArrow, nil, .option) == .step(.increment, shift: false, option: true))
        #expect(press(.home) == .step(.home, shift: false, option: false))
        #expect(press(.end) == .step(.end, shift: false, option: false))
        #expect(press(nil, " ") == .type)
    }

    /// ⌘ and ⌃ keys stay the menu's, and keys the field doesn't use pass on.
    @Test func commandControlAndOtherKeysPassOn() {
        #expect(press(.rightArrow, nil, .command) == nil)
        #expect(press(.leftArrow, nil, [.control, .function]) == nil)
        #expect(press(nil, " ", .command) == nil)
        #expect(press(nil, "k") == nil)
        #expect(press(.tab, "\t") == nil)
        #expect(press(.carriageReturn, "\r") == nil, "Return stays a sheet's default button's")
    }
}
