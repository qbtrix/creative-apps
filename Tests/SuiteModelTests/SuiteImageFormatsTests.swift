// SuiteImageFormatsTests.swift: the suite's one image-format list
// (shared-codecs SC-13, written first; SC-14 builds `SuiteImageFormats` and
// turns it on). Every format the suite reads, by id, type and extensions in
// read order; the four it writes, with TIFF at 8 and 16 bits; a file name's
// extension in any case; and `SuiteTypeRegistry.standard`'s public rows are
// exactly the image rows, read by Photo and Library. Until SC-14 the bodies
// check the registry that exists against the table below.
import SuiteModel
import Testing

@Suite(.disabled("waits on SC-14")) struct SuiteImageFormatsTests {
    /// One expected row: id, type id, extensions (the first is written), write bit depths.
    struct Row: Sendable {
        var id: String, type: String, extensions: [String], writes: [Int]
    }

    static let raw = ["cr2", "cr3", "nef", "nrw", "arw", "sr2", "raf", "orf", "rw2", "dng", "pef", "srw",
                      "3fr", "iiq", "erf", "mos", "x3f"]
    /// Read order for panels.
    static let rows: [Row] = [
        Row(id: "png", type: "public.png", extensions: ["png"], writes: [8]),
        Row(id: "jpeg", type: "public.jpeg", extensions: ["jpg", "jpeg"], writes: [8]),
        Row(id: "heic", type: "public.heic", extensions: ["heic"], writes: [8]),
        Row(id: "heif", type: "public.heif", extensions: ["heif"], writes: []),
        Row(id: "tiff", type: "public.tiff", extensions: ["tif", "tiff"], writes: [8, 16]),
        Row(id: "webp", type: "org.webmproject.webp", extensions: ["webp"], writes: []),
        Row(id: "gif", type: "com.compuserve.gif", extensions: ["gif"], writes: []),
        Row(id: "bmp", type: "com.microsoft.bmp", extensions: ["bmp"], writes: []),
        Row(id: "exr", type: "com.ilm.openexr-image", extensions: ["exr"], writes: []),
        Row(id: "tga", type: "com.truevision.tga-image", extensions: ["tga"], writes: []),
        Row(id: "raw", type: "public.camera-raw-image", extensions: raw, writes: []),
    ]

    /// The registry's public rows: the types no app owns.
    static var publicRows: [SuiteDocumentType] { SuiteTypeRegistry.standard.types.filter { $0.owner == nil } }

    /// Every format, in read order, with its type and extensions.
    @Test func rowsInReadOrder() {
        #expect(Self.publicRows.map(\.id.rawValue) == Self.rows.map(\.type))
        #expect(Self.publicRows.map(\.extensions) == Self.rows.map(\.extensions))
    }

    /// A file name's extension finds its format in any case: a.TIF and a.tiff are TIFF.
    @Test(arguments: ["a.TIF", "a.tiff", "b.WebP", "c.EXR"])
    func extensionInAnyCase(name: String) {
        let ext = String(name.split(separator: ".").last ?? "")
        let row = Self.rows.first { $0.extensions.contains(ext.lowercased()) }
        #expect(SuiteTypeRegistry.standard.type(forExtension: ext)?.id.rawValue == row?.type)
    }

    /// The four written: PNG, JPEG, HEIC and TIFF; TIFF at 8 and 16 bits.
    @Test func writableSetAndBitDepths() {
        #expect(Self.rows.filter { !$0.writes.isEmpty }.map(\.id) == ["png", "jpeg", "heic", "tiff"])
        Issue.record("waits on SC-14: SuiteImageFormats.writable and SuiteImageFormat.tiff.writeBitDepths")
    }

    /// The registry's public rows are the image rows, read by Photo and Library, owned by none.
    @Test func registryPublicRowsAreTheImageRows() {
        #expect(Self.publicRows.count == Self.rows.count)
        #expect(Self.publicRows.allSatisfy { $0.readers == [.photo, .library] })
        #expect(SuiteTypeRegistry.standard.type(forExtension: "webp")?.readers == [.photo, .library])
    }
}
