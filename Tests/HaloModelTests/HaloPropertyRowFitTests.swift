// HaloPropertyRowFitTests.swift: what a TRANSFORM row reserves room for.
// The inspector keeps each row's full title (Position X and Position Y must
// read apart) and measures the row from its title and `widestTypicalText`,
// so the row's layout never flips mid-scrub and its value never sits under
// the bar's marker: the sample must be a text the row really shows, at
// least as long as the row's text for every typical value. Runs on Linux.
import HaloModel
import Testing

@Test func titlesStayFullAndDistinct() {
    let titles = HaloProperty.allCases.map(\.title)
    #expect(Set(titles).count == titles.count)
    #expect(titles.contains("Position X") && titles.contains("Anchor Y"))
}

@Test(arguments: HaloProperty.allCases)
func widestTypicalTextIsAValueTheRowShows(property: HaloProperty) throws {
    let sample = property.widestTypicalText
    let stored = try #require(property.parse(sample))
    #expect(property.range.contains(stored))
    #expect(property.text(stored) == sample)
}

@Test(arguments: HaloProperty.allCases)
func noTypicalValueIsWiderThanTheSample(property: HaloProperty) {
    let sample = property.widestTypicalText.count
    // Shown values from -9999.9 to 9999.9 in tenths' worth of steps, kept in range.
    for tenth in stride(from: -99_999, through: 99_999, by: 37) {
        let stored = Double(tenth) / 10 / property.displayFactor
        guard property.range.contains(stored) else { continue }
        #expect(property.text(stored).count <= sample, "\(property.text(stored))")
    }
}

@Test func samplesForTheFixtureRows() {
    #expect(HaloProperty.x.widestTypicalText == "-9999.9 px")
    #expect(HaloProperty.opacity.widestTypicalText == "100%")
    #expect(HaloProperty.rotation.widestTypicalText == "-10000°")
    #expect(HaloProperty.x.text(560).count <= HaloProperty.x.widestTypicalText.count)
}
