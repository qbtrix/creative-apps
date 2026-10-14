// HaloPropertyTests.swift: an inspector row reads what a person types with or
// without its unit and spaces, refuses what isn't a finite number, and shows
// each property's value in its unit and places. Runs on Linux and macOS.
import HaloModel
import Testing

@Test(arguments: [
    (HaloProperty.rotation, "45", 45.0), (.rotation, "45°", 45), (.rotation, " 45 ° ", 45),
    (.opacity, " 50 %", 0.5), (.opacity, "50", 0.5), (.scaleX, "200%", 2),
    (.x, "960 px", 960), (.y, "-12.5", -12.5),
])
func parseReadsTheNumberBeforeTheUnit(property: HaloProperty, typed: String, stored: Double) {
    #expect(property.parse(typed) == stored)
}

@Test(arguments: ["abc", "inf", "-inf", "nan", "", "45 px"])
func parseRefusesWhatIsNotAFiniteNumber(typed: String) {
    #expect(HaloProperty.rotation.parse(typed) == nil)
}

@Test func textShowsTheUnitAndPlaces() {
    #expect(HaloProperty.x.text(960) == "960.0 px")
    #expect(HaloProperty.anchorY.text(12.34) == "12.3 px")
    #expect(HaloProperty.opacity.text(1) == "100%")
    #expect(HaloProperty.scaleY.text(1.5) == "150%")
    #expect(HaloProperty.rotation.text(45) == "45°")
    #expect(HaloProperty.rotation.text(.nan) == "–")
    #expect(HaloProperty.x.text(.infinity) == "–")
}

@Test func everyPropertyHasATitleAndAStepInsideItsRange() {
    for property in HaloProperty.allCases {
        #expect(!property.title.isEmpty)
        #expect(property.step > 0 && property.range.contains(property.step))
        #expect(HaloProperty(rawValue: property.rawValue) == property)
    }
}

@Test func easingPresetsRoundTripThroughTheirEasing() {
    for preset in HaloEasingPreset.allCases {
        #expect(HaloEasingPreset(preset.easing) == preset)
    }
}
