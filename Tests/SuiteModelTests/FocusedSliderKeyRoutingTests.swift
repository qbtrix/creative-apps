// FocusedSliderKeyRoutingTests.swift (editor-menus, #2487): while an
// inspector slider has focus, ← and → adjust it, as on any Mac; Flare's
// Animate menu steps a frame on them only when the canvas or timeline has
// focus. A click on the item in the menu still steps, and the item never goes
// off under a focused slider (a disabled item would swallow the key).
import SuiteModel
import Testing

struct FocusedSliderKeyRoutingTests {
    /// The Rotation bar has focus: → goes to it, not to Step Forward.
    @Test func aFocusedSliderTakesTheArrow() {
        let item = FocusedSliderKeyRouting.item(sliderFocused: true, fromKey: true, appEnabled: true, appHelp: "")
        #expect(item.route == .slider)
        #expect(item.isEnabled)
        #expect(item.help == FocusedSliderKeyRouting.sliderHelp)
    }

    /// The canvas or timeline has focus: → steps one frame, as the app leaves the item.
    @Test(arguments: [true, false]) func withNoSliderTheArrowSteps(_ appEnabled: Bool) {
        let item = FocusedSliderKeyRouting.item(sliderFocused: false, fromKey: true, appEnabled: appEnabled,
                                                appHelp: "Steps one frame.")
        #expect(item == SliderKeyItem(route: .app, isEnabled: appEnabled, help: "Steps one frame."))
    }

    /// Step Forward is off (the playhead is at the end), yet the focused slider still gets its key.
    @Test func anOffItemStaysOnForTheSlider() {
        let item = FocusedSliderKeyRouting.item(sliderFocused: true, fromKey: true, appEnabled: false, appHelp: "At the end.")
        #expect(item.route == .slider)
        #expect(item.isEnabled)
    }

    /// Choosing Next Frame from the menu with the mouse steps the frame even while a slider has focus.
    @Test(arguments: [true, false]) func aClickInTheMenuSteps(_ appEnabled: Bool) {
        let item = FocusedSliderKeyRouting.item(sliderFocused: true, fromKey: false, appEnabled: appEnabled, appHelp: "")
        #expect(item.route == .app)
        #expect(item.isEnabled == appEnabled)
    }
}
