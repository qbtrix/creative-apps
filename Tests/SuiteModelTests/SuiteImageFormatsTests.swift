// SuiteImageFormatsTests.swift: the suite's one image-format list
// (shared-codecs SC-13 wrote it, SC-14 turned it on). Every format the suite
// reads, by id, type and extensions in read order; the four it writes, with
// TIFF at 8 and 16 bits; a file name's extension in any case; and
// `SuiteTypeRegistry.standard`'s public rows are exactly the image rows, read
// by Photo and Library. The expected table is a literal, so a registry edit
// can't move the test with it.
import Foundation
import SuiteModel
import Testing

@Suite struct SuiteImageFormatsTests {
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

    /// Every format, in read order, with its id, type, extensions and depths; ids round-trip.
    @Test func rowsInReadOrder() throws {
        let all = SuiteImageFormats.all
        #expect(all.map(\.rawValue) == Self.rows.map(\.id))
        #expect(all.map(\.typeID.rawValue) == Self.rows.map(\.type))
        #expect(all.map(\.extensions) == Self.rows.map(\.extensions))
        #expect(all.map(\.writeBitDepths) == Self.rows.map(\.writes))
        #expect(SuiteImageFormats.readable == all)
        #expect(SuiteImageFormats.readExtensions == Self.rows.flatMap(\.extensions))
        for format in all { #expect(SuiteImageFormat(rawValue: format.rawValue) == format) }
        #expect(SuiteImageFormat(rawValue: "psd") == nil)
        let coded = try JSONEncoder().encode([SuiteImageFormat.tiff])
        #expect(String(decoding: coded, as: UTF8.self) == #"["tiff"]"#)
        #expect(try JSONDecoder().decode([SuiteImageFormat].self, from: coded) == [.tiff])
        #expect(throws: (any Error).self) { try JSONDecoder().decode([SuiteImageFormat].self, from: Data(#"["psd"]"#.utf8)) }
    }

    /// TIFF reads a.tif and a.tiff and writes .tif at 8 and 16 bits.
    @Test func tiffBothExtensions() {
        #expect(SuiteImageFormat(fileName: "a.tif") == .tiff)
        #expect(SuiteImageFormat(fileName: "a.tiff") == .tiff)
        #expect(SuiteImageFormat.tiff.fileExtension == "tif")
        #expect(SuiteImageFormat.tiff.writeBitDepths == [8, 16])
        #expect(SuiteImageFormat.tiff.title == "TIFF")
        #expect(SuiteImageFormat.tiff.name == "TIFF image")
        #expect(SuiteImageFormat.jpeg.fileExtension == "jpg")
    }

    /// A file name's extension finds its format in any case; none, or an unlisted one, finds nothing.
    @Test func anyCase() {
        #expect(SuiteImageFormat(fileName: "a.TIF") == .tiff)
        #expect(SuiteImageFormat(fileName: "b.WebP") == .webp)
        #expect(SuiteImageFormat(fileName: "c.EXR") == .exr)
        #expect(SuiteImageFormat(fileName: "IMG_1.CR3") == .cameraRaw)
        #expect(SuiteImageFormat(fileName: "notes.txt") == nil)
        #expect(SuiteImageFormat(fileName: "png") == nil)
        #expect(SuiteImageFormat(fileName: ".png") == nil)
        #expect(SuiteTypeRegistry.standard.type(forExtension: "TIF")?.id == SuiteImageFormat.tiff.typeID)
    }

    /// The four written: PNG, JPEG, HEIC and TIFF. WebP, GIF, BMP, EXR, TGA, HEIF and RAW are read only.
    @Test func writableIsFour() {
        #expect(SuiteImageFormats.writable == [.png, .jpeg, .heic, .tiff])
        for format in [SuiteImageFormat.webp, .gif, .bmp, .exr, .tga, .heif, .cameraRaw] {
            #expect(SuiteImageFormats.readable.contains(format))
            #expect(format.writeBitDepths.isEmpty, "\(format.rawValue)")
        }
        #expect(SuiteImageFormat.exr.family == .highDynamicRange)
        #expect(SuiteImageFormat.cameraRaw.family == .cameraRaw)
        #expect(SuiteImageFormat.png.family == .raster)
    }

    /// The registry's public rows are the image rows, read by Photo and Library, owned by none.
    @Test func registryPublicRowsAreTheImageRows() {
        let all = SuiteImageFormats.all
        #expect(Self.publicRows.map(\.id) == all.map(\.typeID))
        #expect(Self.publicRows.map(\.name) == all.map(\.name))
        #expect(Self.publicRows.map(\.extensions) == all.map(\.extensions))
        #expect(Self.publicRows.allSatisfy { $0.readers == [.photo, .library] })
        #expect(SuiteTypeRegistry.standard.type(forExtension: "webp")?.readers == [.photo, .library])
    }
}
