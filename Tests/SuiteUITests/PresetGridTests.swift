// PresetGridTests.swift: how arrow keys move focus in a PresetGrid, and that
// a toggle chip reports On and Off. macOS only.
import SuiteUI
import SwiftUI
import Testing

/// Six presets in two columns:  0 1 / 2 3 / 4 5.
@Test func arrowsMoveWithinTheGridAndStopAtItsEdges() {
    func move(_ index: Int, _ key: KeyEquivalent) -> Int? {
        PresetGrid<Int>.neighbor(of: index, key, count: 6, columns: 2)
    }
    #expect(move(0, .rightArrow) == 1 && move(1, .leftArrow) == 0)
    #expect(move(0, .downArrow) == 2 && move(3, .upArrow) == 1)
    #expect(move(1, .rightArrow) == nil && move(2, .leftArrow) == nil)
    #expect(move(0, .upArrow) == nil && move(5, .downArrow) == nil)
    #expect(move(0, .return) == nil)
    // A short last row: three columns over five items, nothing below 2.
    #expect(PresetGrid<Int>.neighbor(of: 2, .downArrow, count: 5, columns: 3) == nil)
    #expect(PresetGrid<Int>.neighbor(of: 4, .rightArrow, count: 5, columns: 3) == nil)
}

@Test func aToggleChipReportsOnAndOff() {
    #expect(ChipItem(id: 1, title: "Onion Skin", isOn: true).stateText == "On")
    #expect(ChipItem(id: 1, title: "Onion Skin", isOn: false).stateText == "Off")
}
