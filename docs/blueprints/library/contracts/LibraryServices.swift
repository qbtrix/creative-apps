// LibraryServices.swift: one existential per contract. `.fake` runs every
// member on its fake (the UI track, snapshots, `-LibraryFixture`); `.live`
// takes the platform adapters from LibraryApp and builds the live
// conformances. Until a feature's live conformance lands, its slot holds
// the fake built with an `unavailable` reason, so the control that needs it
// shows disabled with that reason. Each feature edits one line of `live`.
public struct LibraryServices: Sendable {
    public var decoder: any PhotoDecoding
    public var importer: any PhotoImporting
    public var thumbnails: any ThumbnailProviding
    public var culling: any PhotoCulling
    public var coding: any CatalogCoding
    public var store: any CatalogStoring
    public var loupe: any LoupeImaging
    public var develop: any DevelopRendering
    public var crop: any CropGeometry
    public var exporter: any PhotoExporting
    public var writer: any JPEGWriting
    /// Why a member can't act yet, by member name; empty once all are live.
    public var unavailable: [String: String]
    /// True for `.fake` (fixture data on screen); drives the "Preview data" pill.
    public var isPreview: Bool

    public init(decoder: any PhotoDecoding, importer: any PhotoImporting, thumbnails: any ThumbnailProviding,
                culling: any PhotoCulling, coding: any CatalogCoding, store: any CatalogStoring,
                loupe: any LoupeImaging, develop: any DevelopRendering, crop: any CropGeometry,
                exporter: any PhotoExporting, writer: any JPEGWriting,
                unavailable: [String: String] = [:], isPreview: Bool) {
        self.decoder = decoder; self.importer = importer; self.thumbnails = thumbnails
        self.culling = culling; self.coding = coding; self.store = store; self.loupe = loupe
        self.develop = develop; self.crop = crop; self.exporter = exporter; self.writer = writer
        self.unavailable = unavailable; self.isPreview = isPreview
    }

    /// Every member a fake over `photos` (a fixture's photos).
    public static func fake(_ photos: [PhotoItem] = [], mode: FakeMode = .ok) -> LibraryServices {
        let decoder = FakeDecoder(photos: photos, mode: mode)
        return LibraryServices(
            decoder: decoder, importer: FakeImporter(photos: photos, mode: mode),
            thumbnails: FakeThumbnails(mode: mode), culling: FakeCulling(mode: mode),
            coding: FakeCatalogCoding(mode: mode), store: FakeCatalogStore(mode: mode),
            loupe: FakeLoupe(mode: mode), develop: FakeDevelop(mode: mode), crop: FakeCrop(),
            exporter: FakeExporter(mode: mode), writer: FakeJPEGWriter(mode: mode), isPreview: true)
    }

    /// The live services over LibraryApp's platform adapters. While a feature
    /// is unbuilt its member is the fake with a reason (the line it edits).
    public static func live(decoder: any PhotoDecoding, writer: any JPEGWriting,
                            store: any CatalogStoring) -> LibraryServices {
        var services = fake()
        services.decoder = decoder
        services.writer = writer
        services.store = store
        services.unavailable = [
            "importer": "Import isn't connected yet (import).",
            "thumbnails": "Thumbnails aren't connected yet (thumbnails).",
            "culling": "Rating isn't connected yet (cull).",
            "coding": "Saving the catalog isn't connected yet (persist).",
            "loupe": "The loupe isn't connected yet (loupe-viewport).",
            "develop": "Develop isn't connected yet (develop).",
            "crop": "Crop isn't connected yet (crop).",
            "exporter": "Export isn't connected yet (export).",
        ]
        services.isPreview = false
        return services
    }
}
