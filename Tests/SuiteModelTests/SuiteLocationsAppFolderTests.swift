// SuiteLocationsAppFolderTests.swift (adopt-kernel-autosave AK-1 written, AK-2 on): one folder per app under
// the suite root, the flag reaching every app's folder, an earlier build's folder, and the move-once plan that
// never overwrites a file at the new place.
import SuiteModel
import Testing

@Suite struct SuiteLocationsAppFolderTests {
    static let home = "/Users/ana"

    @Test func appFolderHasAppSegment() {
        #expect(SuiteLocations.appFolder("Photo", arguments: [], home: Self.home)
            == "/Users/ana/Library/Application Support/AfterGlow/Photo")
        #expect(SuiteLocations.appFolder("Flare", arguments: [], home: "/Users/ana/")
            == "/Users/ana/Library/Application Support/AfterGlow/Flare")
        #expect(SuiteLocations.appFolder("Photo", arguments: [], home: Self.home)
            != SuiteLocations.appFolder("Library", arguments: [], home: Self.home))
    }

    @Test func flagReachesApp() {
        #expect(SuiteLocations.appFolder("Photo", arguments: ["App", "-SuiteSupportDir", "/t"], home: Self.home) == "/t/Photo")
        #expect(SuiteLocations.appFolder("Library", arguments: ["-SuiteSupportDir", "/t"], home: Self.home) == "/t/Library")
    }

    @Test func legacyFolderIsUnderApplicationSupport() {
        #expect(SuiteLocations.legacyFolder("Photo/Recovery", home: Self.home)
            == "/Users/ana/Library/Application Support/Photo/Recovery")
        #expect(SuiteLocations.legacyFolder("Library", home: "/Users/ana/") == "/Users/ana/Library/Application Support/Library")
    }

    @Test func oldOnlyMoves() {
        #expect(LegacySupport.plan(old: "/o/a", new: "/n/a", exists: { $0 == "/o/a" }) == .move(from: "/o/a", to: "/n/a"))
    }

    @Test func neverOverwrites() {
        #expect(LegacySupport.plan(old: "/o/a", new: "/n/a", exists: { _ in true }) == .keepBoth(old: "/o/a"))
    }

    @Test func nothingToMove() {
        #expect(LegacySupport.plan(old: "/o/a", new: "/n/a", exists: { _ in false }) == .nothing)
        #expect(LegacySupport.plan(old: "/o/a", new: "/n/a", exists: { $0 == "/n/a" }) == .nothing)
    }
}
