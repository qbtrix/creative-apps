// FlareDropCLITests.swift (svg-place, #6202): `afterglow flare file.drop` places a dropped SVG's groups as layers,
// reading the dropped file through the CLI's file system only, and saves them; a dropped SVG that isn't there is
// refused and nothing is written. In process, on a FakeIO; runs on Linux and macOS.
import AfterGlowCLICore
import FlareModel
import Foundation
import Testing

@Suite struct FlareDropCLITests {
    static let twoGroups = Data(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"240\" height=\"80\">"
        + "<g id=\"red\"><rect width=\"100\" height=\"80\" fill=\"#E53935\"/></g>"
        + "<g id=\"blue\"><rect x=\"140\" width=\"100\" height=\"80\" fill=\"#1E88E5\"/></g></svg>").utf8)

    static func blank() throws -> Data {
        try Data(contentsOf: RealJobsHarness.root.appendingPathComponent("Tests/RealJobs/flare/place-svg/input/blank.flare"))
    }

    @Test func aDroppedSVGIsPlacedAsLayersAndSaved() throws {
        let io = FakeIO(files: ["blank.flare": try Self.blank(), "drops/two-groups.svg": Self.twoGroups])
        let code = CLI.run(["flare", "file.drop", "--in", "blank.flare", "--out", "out.flare",
                            "--json", #"{"paths":["drops/two-groups.svg"]}"#], io: io)
        #expect(code == 0, "file.drop exited \(code): \(io.stderr)")
        let saved = try #require(io.files["out.flare"], "nothing saved")
        let doc = try FlareHeadless.open(saved, name: "out.flare")
        #expect(doc.workspace.selectedScene?.layers.map(\.name) == ["red", "blue"])
    }

    @Test func aMissingDroppedSVGIsRefused() throws {
        let io = FakeIO(files: ["blank.flare": try Self.blank()])
        let code = CLI.run(["flare", "file.drop", "--in", "blank.flare", "--out", "out.flare",
                            "--json", #"{"paths":["drops/gone.svg"]}"#], io: io)
        #expect(code != 0)
        #expect(io.files["out.flare"] == nil, "a refused drop wrote a file")
    }
}
