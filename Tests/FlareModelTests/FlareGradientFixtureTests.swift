// FlareGradientFixtureTests.swift: `gradient-circle`, the sample FJ-G1 opens (gradient-fill FG-7). `-FlareSample
// gradient-circle` names it, Circle carries the three-stop linear fill of RJ-F31's gradient-circle.flare, left to
// right, and Rectangle is the solid shape step 5 turns radial.
import FlareCore
import FlareModel
import Testing

@Suite struct FlareGradientFixtureTests {
    @Test func theSampleOpensByName() throws {
        #expect(FlareFixtures.named("gradient-circle") != nil)
        #expect(FlareLaunch(arguments: ["-FlareSample", "gradient-circle"]).source == .sample("gradient-circle"))
        try FlareFormat.validate(try #require(FlareFixtures.named("gradient-circle")))
    }

    @Test func circleIsAThreeStopLinearLeftToRight() throws {
        let scene = try #require(FlareFixtures.named("gradient-circle")?.scenes.first)
        #expect(scene.width == 200 && scene.height == 100)
        #expect(scene.layers.map(\.name) == ["Circle", "Rectangle"])
        let circle = try #require(scene.layers.first { $0.name == "Circle" }?.shapes.first)
        guard case .linear(let stops, let start, let end) = circle.fill else { return #expect(Bool(false), "Circle isn't linear") }
        #expect(stops.map(\.offset) == [0, 0.5, 1])
        #expect(stops.map(\.color) == [FlareColor(r: 0, g: 0, b: 1), FlareColor(r: 0, g: 1, b: 0), FlareColor(r: 0, g: 0, b: 0)])
        #expect(start == Point(x: 10, y: 50) && end == Point(x: 90, y: 50))
    }

    @Test func rectangleIsSolid() throws {
        let scene = try #require(FlareFixtures.named("gradient-circle")?.scenes.first)
        let rectangle = try #require(scene.layers.first { $0.name == "Rectangle" }?.shapes.first)
        guard case .solid = rectangle.fill else { return #expect(Bool(false), "Rectangle isn't solid") }
    }
}
