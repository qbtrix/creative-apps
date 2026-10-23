// AreaToolOptionsTests.swift (area-selection AR-7): every area control names an `AreaSelectCommands` command; the mode
// chip shows the held keys' mode; the ants trace their outline, step 4 times a second and stand still under Reduce
// Motion. macOS only (SuiteUI).
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

private struct AreaFake: AreaSelectTarget {
    var areaRecipe = AreaRecipe.empty, lastAreaRecipe: AreaRecipe?
    var areaHelp: String? { nil }
    mutating func setAreaRecipe(_ recipe: AreaRecipe) throws { areaRecipe = recipe }
}

@MainActor @Suite struct AreaToolOptionsTests {
    @Test func everyControlNamesACommand() {
        let ids = Set(AreaSelectCommands.specs(AreaFake.self).map(\.id))
        for tool in AreaTool.allCases {
            #expect(ids.contains(tool.command), "\(tool) names \(tool.command), which isn't a command")
            let controls = AreaControl.shown(tool)
            #expect(controls.contains(.tool) && controls.contains(.mode) && controls.contains(.feather))
            for control in controls {
                #expect(ids.contains(control.command(tool)), "\(control) on \(tool) is bare: \(control.command(tool))")
            }
        }
        #expect(AreaControl.shown(.wand).contains(.tolerance) && AreaControl.shown(.wand).contains(.allLayers))
        #expect(!AreaControl.shown(.lasso).contains(.tolerance), "the lasso shows the wand's Tolerance")
        #expect(AreaControl.feather.command(.rect) == "select.feather")
        #expect(AreaControl.tolerance.command(.wand) == "select.wand" && AreaControl.mode.command(.ellipse) == "select.ellipse")
        #expect(AreaToolOptions.tools.map(\.identifier) == AreaTool.allCases.map { "suite.area.tool-\($0.rawValue)" })
        #expect(AreaToolOptions.modes.map(\.id) == AreaCombine.allCases)
        #expect(Set(AreaControl.allCases.map(\.identifier)).count == AreaControl.allCases.count)
    }

    @Test func theModeChipFollowsHeldKeys() {
        #expect(AreaToolOptions.shownMode(.subtract, held: []) == .subtract)
        #expect(AreaToolOptions.shownMode(.replace, held: .shift) == .add)
        #expect(AreaToolOptions.shownMode(.replace, held: .option) == .subtract)
        #expect(AreaToolOptions.shownMode(.add, held: [.shift, .option]) == .intersect)
        #expect(AreaToolOptions.shownMode(.intersect, held: .command) == .intersect, "Command alone changed the mode")
    }

    @Test func theAntsTraceTheirOutline() {
        let outline: [[Point]] = [[Point(x: 10, y: 10), Point(x: 90, y: 10), Point(x: 50, y: 60)], [Point(x: 1, y: 2), Point(x: 3, y: 4)]]
        let lines = AreaAnts.lines(outline, zoom: 1)
        #expect(lines == outline.map { $0.map { CGPoint(x: $0.x, y: $0.y) } })
        #expect(AreaAnts.lines(outline, zoom: 2).first?.last == CGPoint(x: 100, y: 120))
        #expect(AreaAnts.lines(outline, zoom: .nan) == lines, "a bad zoom isn't 1")
        // A lasso in progress closes back to its first point once it has three.
        #expect(AreaAnts.band([Point(x: 0, y: 0), Point(x: 5, y: 0)], zoom: 1).count == 2)
        #expect(AreaAnts.band(outline[0], zoom: 1).last == CGPoint(x: 10, y: 10))
    }

    @Test func antsStillUnderReduceMotion() {
        for time in [0, 0.25, 0.5, 1.75, 1000.1] {
            #expect(AreaAnts.phase(at: time, reduceMotion: true) == 0, "the ants moved at \(time) under Reduce Motion")
        }
        #expect(!AreaAnts.animates(reduceMotion: true, snapshot: false) && !AreaAnts.animates(reduceMotion: false, snapshot: true))
        #expect(AreaAnts.animates(reduceMotion: false, snapshot: false))
        #expect(AreaAnts.stepsPerSecond == 4)
        let phases = [0, 0.25, 0.5, 0.75].map { AreaAnts.phase(at: $0, reduceMotion: false) }
        #expect(Set(phases).count == 4, "the ants don't step 4 times a second: \(phases)")
        #expect(AreaAnts.phase(at: 1, reduceMotion: false) == phases[0], "a second isn't one full march")
        #expect(AreaAnts.phase(at: .infinity, reduceMotion: false) == 0)
    }
}
