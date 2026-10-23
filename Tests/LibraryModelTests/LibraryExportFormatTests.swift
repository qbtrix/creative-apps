// LibraryExportFormatTests.swift: EX-7, the format rules (packet
// docs/blueprints/library/features/export.md; slice EX-c). Quality applies to
// the lossy formats only, a written name maps back to its format, and a format
// this Mac can't write says so.
import Foundation
import Testing

@testable import LibraryModel

@Suite struct LibraryExportFormatTests {
    @Test func qualityAppliesToJPEGAndHEICOnly() {
        #expect(ExportFormat.allCases.filter(\.usesQuality) == [.jpeg, .heic])
        #expect(!ExportFormat.png.usesQuality && !ExportFormat.tiff.usesQuality)
    }

    @Test func fileNamesMapToTheirFormat() {
        #expect(ExportFormat.forFileName("a.JPG") == .jpeg)
        #expect(ExportFormat.forFileName("a.jpeg") == .jpeg)
        #expect(ExportFormat.forFileName("a.tif") == .tiff)
        #expect(ExportFormat.forFileName("a.tiff") == .tiff)
        #expect(ExportFormat.forFileName("a.png") == .png)
        #expect(ExportFormat.forFileName("a.heic") == .heic)
        #expect(ExportFormat.forFileName("IMG_0001 2.TIFF") == .tiff)
    }

    @Test func otherNamesMapToNothing() {
        for name in ["a.gif", "a.heif", "a.xmp", "a.jp", "a.pngx", "noextension", ".jpg", "a.", "a.jpg.txt", ""] {
            #expect(ExportFormat.forFileName(name) == nil, "\(name) mapped to a format")
        }
    }

    @Test func aFormatThisMacCantWriteSaysWhy() {
        #expect(ExportFormat.heic.help(writable: [.jpeg, .png, .tiff]) == "This Mac can't write HEIC files.")
        #expect(ExportFormat.png.help(writable: [.jpeg]) == "This Mac can't write PNG files.")
        #expect(ExportFormat.jpeg.help(writable: []) == "This Mac can't write JPEG files.")
    }

    @Test func aWritableFormatHasNoHelp() {
        for format in ExportFormat.allCases {
            #expect(format.help(writable: Set(ExportFormat.allCases)) == nil, "\(format) refused while writable")
        }
        #expect(ExportFormat.png.help(writable: [.png]) == nil)
    }

    @Test func thePlanNamesThePNGExtension() {
        let photo = LibraryFixtures.photos(named: "shoot")[0]
        let options = ExportOptions(folder: "/out", format: .png)
        let plan = FakeExporter().plan([photo], options: options, existingNames: [])
        #expect(plan.items.map(\.fileName) == ["IMG_0001.png"])
        #expect(plan.items.allSatisfy { ExportFormat.forFileName($0.fileName) == .png })
    }
}
