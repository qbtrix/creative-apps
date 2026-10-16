// FlareLaunch.swift: Flare's launch flags (draw-key-save, DK-1). `-FlareFixture <name>` opens a fixture on fakes,
// `-FlareSample <name>` opens the same document on the real services, `-FlareOpenFile <path>` names a file the window
// reads (DK-12), and `-FlareSaveTo` / `-FlareExportTo` name the folders saves and exports go to. Unknown flags, a flag
// with no value and an unknown fixture name are ignored, so a bad launch opens an empty window, never a crash.
import FlareCore

public struct FlareLaunch: Sendable, Equatable {
    public enum Source: Sendable, Equatable { case none, fixture(String), sample(String), file(String) }

    public var source: Source
    /// `-FlareSaveTo`: the folder a save writes to without a panel.
    public var saveFolder: String?
    /// `-FlareExportTo`: the folder an export writes to (read by export later).
    public var exportFolder: String?

    /// Walks `arguments` (the process's, program name included or not). The last source flag wins.
    public init(arguments: [String]) {
        source = .none
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let flag = arguments[index]
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, !arguments[next].isEmpty, !arguments[next].hasPrefix("-") else {
                index = next
                continue
            }
            let value = arguments[next]
            switch flag {
            case "-FlareFixture": source = FlareFixtures.named(value) == nil ? .none : .fixture(value)
            case "-FlareSample": source = FlareFixtures.named(value) == nil ? .none : .sample(value)
            case "-FlareOpenFile": source = .file(value)
            case "-FlareSaveTo": saveFolder = value
            case "-FlareExportTo": exportFolder = value
            default:
                index = next
                continue
            }
            index = arguments.index(after: next)
        }
    }

    /// True only for `-FlareFixture`: journeys and snapshots run on fakes.
    public var usesFakes: Bool {
        if case .fixture = source { true } else { false }
    }
}

extension FlareWorkspace {
    /// Services by source; `.fixture` and `.sample` open their fixture document. `.file` opens nothing here: the
    /// window reads the file off the main thread (DK-12).
    public init(launch: FlareLaunch) {
        self.init(services: launch.usesFakes ? .fake() : .live)
        switch launch.source {
        case .fixture(let name), .sample(let name):
            if let document = FlareFixtures.named(name) { load(document) }
        case .none, .file:
            break
        }
    }
}
