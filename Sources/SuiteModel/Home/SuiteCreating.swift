// SuiteCreating.swift: the live DocumentCreating (UC-3, HM-1b), pure. Each
// app's New tile and presets; a missing app's tile is disabled. No reason of
// its own: HomeModel applies `pending["sending"]`. FakeCreating shares these.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteCreating: DocumentCreating {
    public init() {}

    /// Mirrors each app's own preset list (Flare's New Animation sheet, Halo's New Composition, …).
    public static let presets: [SuiteApp: [NewDocumentPreset]] = [
        .flare: [NewDocumentPreset(id: "flare.hd", app: .flare, title: "1080p 16:9", detail: "1920 × 1080, 24 fps", parameters: ["width": "1920", "height": "1080", "fps": "24"]),
                 NewDocumentPreset(id: "flare.square", app: .flare, title: "Square", detail: "1080 × 1080, 24 fps", parameters: ["width": "1080", "height": "1080", "fps": "24"]),
                 NewDocumentPreset(id: "flare.vertical", app: .flare, title: "Vertical 9:16", detail: "1080 × 1920, 30 fps", parameters: ["width": "1080", "height": "1920", "fps": "30"])],
        .design: [NewDocumentPreset(id: "design.blank", app: .design, title: "Blank", detail: "One page")],
        .photo: [NewDocumentPreset(id: "photo.sheet", app: .photo, title: "New Image…", detail: "Choose a size")],
        .library: [NewDocumentPreset(id: "library.import", app: .library, title: "Import Folder…", detail: "PNG, JPEG, HEIC")],
        .halo: [NewDocumentPreset(id: "halo.sheet", app: .halo, title: "New Composition…", detail: "Choose size, rate and length")],
    ]

    /// Each tile's title, as its app's File > New names it.
    public static let titles: [SuiteApp: String] = [.flare: "New Animation", .design: "New Design", .photo: "New Image",
                                                     .library: "Import Photos…", .halo: "New Composition"]

    public func tiles(missing: Set<SuiteApp>) -> [NewTile] {
        SuiteApp.apps.map { app in
            NewTile(app: app, title: Self.titles[app] ?? app.displayName, presets: Self.presets[app] ?? [],
                    disabledReason: missing.contains(app) ? SuiteError.appMissing(app).message : nil)
        }
    }

    public func handOff(for preset: NewDocumentPreset, id: String, at date: Date) -> HandOff {
        HandOff(id: id, from: .launcher, to: preset.app, verb: .new, preset: preset, createdAt: date)
    }
}
