// PhotoLaunchOptionsTests.swift: the launch arguments (S-12). `-PhotoFixture`
// names a fixture or is kept as an unknown name, `-PhotoWindowWidth` is kept
// only within 880...4096, and the launch workspace runs on the fakes under a
// fixture (empty with "No fixture named <name>." for an unknown one) and is
// nil without one, so the window stays on `.live`. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoLaunchOptionsTests {
    @Test func aFixtureNameParses() {
        let options = PhotoLaunchOptions(arguments: ["-PhotoFixture", "layered"])
        #expect(options.fixture == .layered)
        #expect(options.unknownFixture == nil)
    }

    @Test func anUnknownNameIsKept() {
        let options = PhotoLaunchOptions(arguments: ["/path/PhotoApp", "-PhotoFixture", "nope"])
        #expect(options.fixture == nil)
        #expect(options.unknownFixture == "nope")
    }

    @Test(arguments: [("500", nil), ("1200", 1200), ("880", 880), ("4096", 4096), ("4097", nil), ("wide", nil), ("nan", nil)]
          as [(String, Double?)])
    func theWindowWidthIsKeptOnlyInRange(_ text: String, _ width: Double?) {
        #expect(PhotoLaunchOptions(arguments: ["-PhotoWindowWidth", text]).windowWidth == width)
    }

    @Test func bothFlagsTogether() {
        let options = PhotoLaunchOptions(arguments: ["-PhotoWindowWidth", "1400", "-PhotoFixture", "sample"])
        #expect(options.fixture == .sample)
        #expect(options.windowWidth == 1400)
    }

    @Test(arguments: [[], ["/path/PhotoApp"], ["-PhotoFixture"], ["-PhotoWindowWidth"], ["-Other", "x"]] as [[String]])
    func noValueGivesNothing(_ arguments: [String]) {
        let options = PhotoLaunchOptions(arguments: arguments)
        #expect(options.fixture == nil && options.unknownFixture == nil && options.windowWidth == nil)
    }

    @Test func aFixtureLaunchesOnFakes() throws {
        let workspace = try #require(PhotoWorkspace.launch(PhotoLaunchOptions(arguments: ["-PhotoFixture", "sample"])))
        #expect(workspace.isPreviewData)
        #expect(workspace.canvas?.width == 800)
        #expect(workspace.statusMessage == nil)
    }

    @Test func anUnknownFixtureLaunchesEmptyWithAMessage() throws {
        let workspace = try #require(PhotoWorkspace.launch(PhotoLaunchOptions(arguments: ["-PhotoFixture", "nope"])))
        #expect(workspace.isPreviewData)
        #expect(workspace.canvas == nil && workspace.layers.isEmpty)
        #expect(workspace.statusMessage == "No fixture named nope.")
    }

    @Test func withoutAFixtureTheWindowStaysLive() {
        #expect(PhotoWorkspace.launch(PhotoLaunchOptions(arguments: ["-PhotoWindowWidth", "1200"])) == nil)
        #expect(!PhotoWorkspace(services: .live).isPreviewData)
        #expect(!PhotoWorkspace().isPreviewData)
    }
}
