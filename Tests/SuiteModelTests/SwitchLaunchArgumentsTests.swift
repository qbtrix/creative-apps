// SwitchLaunchArgumentsTests.swift: a cold-launched app takes its own flags
// and the suite-wide ones, never another app's (blueprint 2.6).
import SuiteModel
import Testing

@Suite struct SwitchLaunchArgumentsTests {
    @Test func designGetsItsOwnFlagAndTheSuiteFlagsNeverFlares() {
        let args = ["-FlareSaveTo", "a", "-DesignSaveTo", "x", "-SuiteSupportDir", "/s"]
        #expect(LaunchArguments.forward(args, to: .design) == ["-DesignSaveTo", "x", "-SuiteSupportDir", "/s"])
    }

    @Test func flareNeverGetsDesignsFlags() {
        let args = ["-FlareSaveTo", "a", "-DesignSaveTo", "x", "-SuiteSupportDir", "/s"]
        #expect(LaunchArguments.forward(args, to: .flare) == ["-FlareSaveTo", "a", "-SuiteSupportDir", "/s"])
    }

    @Test func aFlagWithNoValueIsKeptAlone() {
        let args = ["-SuiteFixtureDocuments", "-FlareSaveTo", "a"]
        #expect(LaunchArguments.forward(args, to: .flare) == ["-SuiteFixtureDocuments", "-FlareSaveTo", "a"])
    }

    @Test func libraryKeepsItsSampleAndCatalogFlags() {
        let args = ["-LibrarySample", "-LibraryCatalogDir", "/c", "-SuitePerfProbe", "1", "-HaloSaveTo", "h"]
        #expect(LaunchArguments.forward(args, to: .library) == ["-LibrarySample", "-LibraryCatalogDir", "/c", "-SuitePerfProbe", "1"])
    }
}
