// PhotoLaunchOptionsTests.swift: the launch arguments (S-12). `-PhotoFixture`
// names a fixture or is kept as an unknown name, other flags (SuiteUI's
// `-SuiteWindowSize` among them) are skipped, and the launch workspace runs on
// the fakes under a fixture (empty with "No fixture named <name>." for an unknown one) and is
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

    @Test func theWindowSizeFlagIsSkipped() {
        let options = PhotoLaunchOptions(arguments: ["-SuiteWindowSize", "1400x900", "-PhotoFixture", "sample"])
        #expect(options.fixture == .sample)
        #expect(options.unknownFixture == nil)
    }

    @Test(arguments: [[], ["/path/PhotoApp"], ["-PhotoFixture"], ["-SuiteWindowSize", "1024x768"], ["-Other", "x"]]
          as [[String]])
    func noValueGivesNothing(_ arguments: [String]) {
        let options = PhotoLaunchOptions(arguments: arguments)
        #expect(options.fixture == nil && options.unknownFixture == nil)
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
        #expect(PhotoWorkspace.launch(PhotoLaunchOptions(arguments: ["-SuiteWindowSize", "1200x800"])) == nil)
        #expect(!PhotoWorkspace(services: .live).isPreviewData)
        #expect(!PhotoWorkspace().isPreviewData)
    }
}
