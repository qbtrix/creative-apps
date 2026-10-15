// LibraryLaunch.swift: the launch arguments of blueprint 4.1, parsed from the
// process arguments, and the services and first photos they pick. Unknown
// flags are ignored; a value flag with no value after it stays unset.

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

    public init(arguments: [String]) {
        let switches: Set<String> = [
            "-LibraryImportOnLaunch", "-LibraryPerfProbe", "-LibraryTestValues", "-LibraryReduceMotion",
        ]
        let valued: Set<String> = [
            "-LibraryFixture", "-LibraryCatalogDir", "-LibraryImportFolder", "-LibraryExportTo",
            "-LibraryFakeMode", "-LibraryWindowSize",
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
    }

    /// Fakes over the fixture's photos when there is a fixture, else the live
    /// services over the app's platform adapters.
    public func services(decoder: any PhotoDecoding, writer: any JPEGWriting,
                         store: any CatalogStoring) -> LibraryServices {
        guard let fixture else { return .live(decoder: decoder, writer: writer, store: store) }
        return .fake(LibraryFixtures.photos(named: fixture), mode: fakeMode)
    }

    /// The catalog's photos at launch: the fixture's, except `shoot-unimported`
    /// starts empty so a journey can import the shoot.
    public var initialPhotos: [PhotoItem] {
        fixture == "shoot-unimported" ? [] : LibraryFixtures.photos(named: fixture)
    }
}
