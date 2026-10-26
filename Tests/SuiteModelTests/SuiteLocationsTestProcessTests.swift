// SuiteLocationsTestProcessTests.swift: a test process never resolves the
// user's real ~/Library/Application Support/AfterGlow (#5221). Arguments that
// name a test bundle (`*.xctest`, as `swift test` launches on macOS and Linux)
// get one temporary folder per process; a `-SuiteSupportDir` still wins, and
// an app's own arguments keep the real folder. The last test is the guard:
// this very process's arguments must not resolve to the real folder, so a
// change in how SwiftPM launches tests fails here instead of writing there.
import Foundation
import SuiteModel
import Testing

@Suite struct SuiteLocationsTestProcessTests {
    static let home = "/Users/ana"
    static let real = "/Users/ana/Library/Application Support/AfterGlow"

    @Test func aTestBundleGetsATemporaryFolder() {
        let launches = [
            ["/usr/bin/xctest", "/b/.build/debug/CreativeAppsPackageTests.xctest"],
            ["/b/.build/debug/CreativeAppsPackageTests.xctest", "--testing-library", "swift-testing"],
            ["swiftpm-testing-helper", "--test-bundle-path",
             "/b/.build/debug/CreativeAppsPackageTests.xctest/Contents/MacOS/CreativeAppsPackageTests"],
        ]
        for arguments in launches {
            let folder = SuiteLocations.supportFolder(arguments: arguments, home: Self.home)
            #expect(folder == SuiteLocations.testProcessFolder, "\(arguments)")
            #expect(!folder.hasPrefix(Self.home))
        }
        #expect(SuiteLocations.appFolder("Photo", arguments: launches[0], home: Self.home)
            == SuiteLocations.testProcessFolder + "/Photo")
    }

    @Test func theFlagStillWinsInATestProcess() {
        let arguments = ["/b/X.xctest", SuiteLocations.supportDirFlag, "/t"]
        #expect(SuiteLocations.supportFolder(arguments: arguments, home: Self.home) == "/t")
    }

    @Test func anAppKeepsTheRealFolder() {
        let arguments = ["/Applications/AfterGlow.app/Contents/MacOS/Flare", "-NSDocumentRevisionsDebugMode", "YES"]
        #expect(SuiteLocations.supportFolder(arguments: arguments, home: Self.home) == Self.real)
    }

    @Test func thisProcessNeverResolvesTheRealFolder() {
        let home = NSHomeDirectory()
        let real = SuiteLocations.supportFolder(arguments: [], home: home)
        let resolved = SuiteLocations.supportFolder(arguments: ProcessInfo.processInfo.arguments, home: home)
        #expect(resolved != real, "this test process resolves the real support folder; arguments: \(ProcessInfo.processInfo.arguments)")
        #expect(!resolved.hasPrefix(real))
    }
}
