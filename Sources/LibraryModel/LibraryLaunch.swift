// LibraryLaunch.swift: the launch arguments of blueprint 4.1, parsed from the
// process arguments, and the services and first photos they pick. Unknown
// flags are ignored; a value flag with no value after it stays unset.
// `-LibraryLargeFixture <count>` (large-catalog LG-2) wins over `-LibraryFixture`.

import SuiteModel

/// `-LibraryWindowSize <w>x<h>`: the window's initial content size.
public struct LibraryWindowSize: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// "WxH" with both at least 1, else nil.
    public init?(parsing text: String) {
        let parts = text.split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2, let width = Int(parts[0]), let height = Int(parts[1]),
              width >= 1, height >= 1 else { return nil }
        self.init(width: width, height: height)
    }
}

public struct LibraryLaunch: Sendable, Equatable {
    /// `-LibraryFixture <name>`: fake services and that fixture's photos.
    public let fixture: String?
    /// `-LibraryCatalogDir <path>`: where `catalog.json` lives.
    public let catalogDir: String?
    /// `-LibraryImportFolder <path>`: File > Import Folder… imports this, no panel.
    public let importFolder: String?
    /// `-LibraryImportOnLaunch`: import `importFolder` right after launch.
    public let importOnLaunch: Bool
    /// `-LibraryExportTo <path>`: the export sheet's folder, no panel.
    public let exportTo: String?
    /// `-LibraryFakeMode ok|fail|slow`; anything else is `.ok`.
    public let fakeMode: FakeMode
    /// `-LibraryPerfProbe`: expose `suite.perf`.
    public let perfProbe: Bool
    /// `-LibraryTestValues`: compute the loupe checksum and other test-only values.
    public let testValues: Bool
    /// `-LibraryReduceMotion`: treat Reduce Motion as on.
    public let reduceMotion: Bool
    /// `-LibraryWindowSize <w>x<h>`; nil when absent or malformed.
    public let windowSize: LibraryWindowSize?
    /// `-LibraryLargeFixture <count>`: fakes over the large fixture's `count` photos; nil unless at least 1.
    public let largeFixture: Int?
    /// `-LibraryFixtureBackups <n>` with n at least 1: the fixture's catalog gets backups (`backups(catalogFolder:)`).
    public let fixtureBackups: Bool

    public init(arguments: [String]) {
        let switches: Set<String> = [
            "-LibraryImportOnLaunch", "-LibraryPerfProbe", "-LibraryTestValues", "-LibraryReduceMotion",
        ]
        let valued: Set<String> = [
            "-LibraryFixture", "-LibraryCatalogDir", "-LibraryImportFolder", "-LibraryExportTo",
            "-LibraryFakeMode", "-LibraryWindowSize", "-LibraryLargeFixture", "-LibraryFixtureBackups",
        ]
        var values: [String: String] = [:]
        var present: Set<String> = []
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            index += 1
            if switches.contains(argument) {
                present.insert(argument)
            } else if valued.contains(argument), index < arguments.endIndex {
                values[argument] = arguments[index]
                index += 1
            }
        }
        fixture = values["-LibraryFixture"]
        catalogDir = values["-LibraryCatalogDir"]
        importFolder = values["-LibraryImportFolder"]
        importOnLaunch = present.contains("-LibraryImportOnLaunch")
        exportTo = values["-LibraryExportTo"]
        fakeMode = values["-LibraryFakeMode"].flatMap(FakeMode.init(rawValue:)) ?? .ok
        perfProbe = present.contains("-LibraryPerfProbe")
        testValues = present.contains("-LibraryTestValues")
        reduceMotion = present.contains("-LibraryReduceMotion")
        windowSize = values["-LibraryWindowSize"].flatMap(LibraryWindowSize.init(parsing:))
        largeFixture = values["-LibraryLargeFixture"].flatMap { Int($0) }.flatMap { $0 >= 1 ? $0 : nil }
        fixtureBackups = values["-LibraryFixtureBackups"].flatMap { Int($0) }.map { $0 >= 1 } ?? false
    }

    /// Fakes over the fixture's photos when there is a fixture, else the live
    /// services over the app's platform adapters (sidecars off until passed).
    public func services(decoder: any PhotoDecoding, writer: any JPEGWriting, store: any CatalogStoring,
                         looks: any PresetStoring = FakePresetStore(),
                         sidecars: any SidecarWriting = UnconnectedSidecars()) -> LibraryServices {
        if largeFixture != nil { return .fake(initialPhotos, mode: fakeMode) }
        guard let fixture else { return .live(decoder: decoder, writer: writer, store: store, looks: looks, sidecars: sidecars) }
        return .fake(LibraryFixtures.photos(named: fixture), mode: fakeMode)
    }

    /// The catalog's photos at launch: the fixture's, except `shoot-unimported`
    /// and `cameras-unimported` start empty so a journey can import them;
    /// the large fixture's photos (no files) under `-LibraryLargeFixture`.
    public var initialPhotos: [PhotoItem] {
        if let largeFixture { return LibraryFixtures.largePhotos(count: largeFixture, folder: nil) }
        return fixture?.hasSuffix("-unimported") == true ? [] : LibraryFixtures.photos(named: fixture)
    }
}

extension LibraryCatalog {
    /// The window's catalog at launch: `services` (from `launch.services`),
    /// the launch's first photos in the grid, and the test-only values on
    /// under `-LibraryTestValues`.
    public init(launch: LibraryLaunch, services: LibraryServices) {
        self.init(services: services)
        load(launch.initialPhotos)
        showsTestValues = launch.testValues
    }
}
