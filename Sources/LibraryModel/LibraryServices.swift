// LibraryServices.swift: one existential per contract. `.fake` runs every
// member on its fake (the UI track, snapshots, `-LibraryFixture`); `.live`
// takes the platform adapters from LibraryApp and builds the `Live…`
// conformances. Until a feature lands, its `Live…` type is the spine's stub,
// whose `unavailable` reason disables the controls that need it.
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

    /// The live services over LibraryApp's platform adapters. Every member is
    /// its `Live…` type from the start; a feature replaces its own `Live/`
    /// file and sets that type's `unavailable` to nil, so nobody edits this.
    public static func live(decoder: any PhotoDecoding, writer: any JPEGWriting,
                            store: any CatalogStoring) -> LibraryServices {
        let develop = LiveDevelop()
        let reasons: [(String, String?)] = [
            ("importer", LiveImporter.unavailable), ("thumbnails", LiveThumbnails.unavailable),
            ("culling", LiveCulling.unavailable), ("coding", LiveCatalogCoding.unavailable),
            ("loupe", LiveLoupeImaging.unavailable), ("develop", LiveDevelop.unavailable),
            ("crop", LiveCrop.unavailable), ("exporter", LiveExporter.unavailable),
        ]
        var unavailable: [String: String] = [:]
        for (member, reason) in reasons { if let reason { unavailable[member] = reason } }
        return LibraryServices(
            decoder: decoder, importer: LiveImporter(decoder: decoder),
            thumbnails: LiveThumbnails(decoder: decoder, develop: develop), culling: LiveCulling(),
            coding: LiveCatalogCoding(), store: store, loupe: LiveLoupeImaging(decoder: decoder, develop: develop),
            develop: develop, crop: LiveCrop(), exporter: LiveExporter(decoder: decoder, develop: develop),
            writer: writer, unavailable: unavailable, isPreview: false)
    }
}
