// FillMemoryTests.swift (gradient-fill, supervisor's call 2026-10-21): switching types is exploration, so it keeps
// settings. `FillMemory` holds the last linear angle and the last radial centre and radius; `converted` gives them
// back (0° and the box's centre and half diagonal only for a gradient that never had them), and `fill.type` saves the
// memory with the fill on a target that keeps it, as one undo step.
import Testing
import SuiteKernel

/// One layer that keeps its fill's memory beside it, as an app saves it.
struct MemoryDoc: GradientFillTarget {
    var fill: Fill, memory = FillMemory(), history = History<Fill>()
    let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    var fillSelection: FillSelection? { FillSelection(fill: fill, box: box, memory: memory) }
    var fillHelp: String? { nil }
    mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        history.record(name, self.fill, key: drag.map { "\(name):\($0)" }); self.fill = fill
    }
    mutating func setFill(_ fill: Fill, memory: FillMemory, in box: Rect, name: String, drag: String?) throws {
        try setFill(fill, in: box, name: name, drag: drag); self.memory = memory
    }
}

@Suite struct FillMemoryTests {
    static let square = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    static let stops = [GradientStop(offset: 0, color: .black), GradientStop(offset: 1, color: .white)]
    static let flat = Fill.linear(stops: stops, start: Point(x: 0, y: 50), end: Point(x: 100, y: 50))
    static func angle(_ fill: Fill) -> Double { GradientRules.angle(of: fill) ?? -1 }

    @Test func linearRadialLinearKeepsTheAngle() {
        let turned = GradientRules.rotated(Self.flat, to: 45, in: Self.square)
        let memory = GradientRules.remembering(turned, in: FillMemory())
        let radial = GradientRules.converted(turned, to: .radial, in: Self.square, memory: memory)
        let back = GradientRules.converted(radial, to: .linear, in: Self.square, memory: GradientRules.remembering(radial, in: memory))
        #expect(memory.angle.map { abs($0 - 45) < 1e-9 } == true && abs(Self.angle(back) - 45) < 1e-9)
        #expect(Self.angle(GradientRules.converted(radial, to: .linear, in: Self.square)) == 0)
    }
    @Test func radialLinearRadialKeepsTheCentreAndRadius() {
        let radial = Fill.radial(stops: Self.stops, center: Point(x: 20, y: 30), radius: 15)
        let memory = GradientRules.remembering(radial, in: FillMemory(angle: 90))
        #expect(memory == FillMemory(angle: 90, center: Point(x: 20, y: 30), radius: 15))
        let linear = GradientRules.converted(radial, to: .linear, in: Self.square, memory: memory)
        #expect(abs(Self.angle(linear) - 90) < 1e-9)
        #expect(GradientRules.converted(linear, to: .radial, in: Self.square, memory: memory) == radial)
    }
    @Test func typeSwitchesSaveTheMemoryAsOneStepEach() throws {
        let catalog = try CommandCatalog(app: "test", GradientCommands.specs(MemoryDoc.self), history: { $0.history })
        var doc = MemoryDoc(fill: GradientRules.rotated(Self.flat, to: 45, in: Self.square))
        _ = try catalog.run("fill.type", params: .object(["type": .string("radial")]), on: &doc)
        _ = try catalog.run("fill.type", params: .object(["type": .string("linear")]), on: &doc)
        #expect(abs(Self.angle(doc.fill) - 45) < 1e-9 && doc.history.steps.count == 2)
        var plain = FillDoc(fill: GradientRules.rotated(Self.flat, to: 45, in: Self.square))
        let plainCatalog = try #require(GradientCommandsTests.catalog)
        _ = try plainCatalog.run("fill.type", params: .object(["type": .string("radial")]), on: &plain)
        _ = try plainCatalog.run("fill.type", params: .object(["type": .string("linear")]), on: &plain)
        #expect(Self.angle(plain.fill) == 0)
    }
}
