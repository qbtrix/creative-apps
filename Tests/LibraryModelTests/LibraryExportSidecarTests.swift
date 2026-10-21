// LibraryExportSidecarTests.swift: EX-16, the XMP sidecar beside an export
// (packet docs/blueprints/library/features/export.md, slice EX-f). Written by
// EX-15 before its code (lead.md, contract rule 13); EX-16, which fills
// `ExportSidecar.xmp`, enabled them and added the order and basics checks.
import CoreColor
import Foundation
import Testing

@testable import LibraryModel

@Suite struct LibraryExportSidecarTests {
    /// IMG_0001 taken 2026-06-01 10:07 UTC: 3 stars, a pick, Red, exposure 0.5, no crop.
    func photo(name: String = "IMG_0001", rating: Int = 3, flag: PhotoFlag = .pick,
               develop: DevelopSettings = DevelopSettings.neutral.setting(.exposure, to: 0.5)) throws -> PhotoItem {
        PhotoItem(id: "/shoot/\(name).jpg", name: name, captureDate: try Date("2026-06-01T10:07:00Z", strategy: .iso8601),
                  color: Color3(0.5, 0.5, 0.5), rating: rating, label: .red, flag: flag,
                  path: "/shoot/\(name).jpg", pixelSize: PixelSize(width: 6000, height: 4000), develop: develop)
    }

    func packet(_ photo: PhotoItem) throws -> String {
        let data = try #require(ExportSidecar.xmp(for: photo, metadata: .all), "no packet: \(ExportSidecar.unavailable ?? "")")
        return try #require(String(data: data, encoding: .utf8), "the packet isn't UTF-8")
    }

    @Test func packetHoldsEveryValueInAFixedOrder() throws {
        let expected = """
            <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\
            <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/" \
            xmlns:library="https://github.com/qbtrix/creative-apps/ns/library/1.0/" \
            xmp:Rating="3" xmp:Label="Red" xmp:CreateDate="2026-06-01T10:07:00Z" \
            library:Name="IMG_0001" library:Flag="pick" library:Exposure="0.5"/></rdf:RDF></x:xmpmeta>
            """
        #expect(try packet(photo()) == expected)
        #expect(ExportSidecar.unavailable == nil)
    }

    @Test func valuesAreXMLEscaped() throws {
        let text = try packet(photo(name: "R&D \"final\" <1>"))
        #expect(text.contains("R&amp;D &quot;final&quot; &lt;1&gt;"))
        #expect(!text.contains("R&D"))
        #expect(try packet(photo(name: "it's")).contains("library:Name=\"it&apos;s\""))
    }

    @Test func anUnratedUnlabelledUnflaggedPhotoWritesOnlyItsBasics() throws {
        let item = PhotoItem(id: "a", name: "a", captureDate: Date(timeIntervalSince1970: 0), color: Color3(0, 0, 0))
        let text = try packet(item)
        #expect(text.hasSuffix("""
            xmp:Rating="0" xmp:CreateDate="1970-01-01T00:00:00Z" library:Name="a"/></rdf:RDF></x:xmpmeta>
            """))
    }

    @Test func slidersFollowThePanelOrderAndCropComesLast() throws {
        let crop = CropSettings(angle: -1.5, rect: UnitRect(x: 0, y: 0.25, width: 1, height: 0.5), aspect: .free)
        let develop = DevelopSettings.neutral.setting(.saturation, to: 10).setting(.contrast, to: -20)
            .setting(.exposure, to: 1).setting(crop: crop)
        let text = try packet(photo(develop: develop))
        #expect(text.contains("""
            library:Flag="pick" library:Exposure="1" library:Contrast="-20" library:Saturation="10" \
            library:CropAngle="-1.5" library:Crop="0 0.25 1 0.5"/>
            """))
    }

    @Test func aRejectIsRatedMinusOne() throws {
        let text = try packet(photo(rating: 2, flag: .reject))
        #expect(text.contains("xmp:Rating=\"-1\""))
        #expect(text.contains("library:Flag=\"reject\""))
    }

    @Test func noCropWritesNoCrop() throws {
        #expect(!(try packet(photo())).contains("library:Crop"))
        let crop = CropSettings(angle: 2, rect: UnitRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), aspect: .free)
        let cropped = try packet(photo(develop: DevelopSettings.neutral.setting(crop: crop)))
        #expect(cropped.contains("library:CropAngle=\"2\""))
        #expect(cropped.contains("library:Crop=\""))
    }

    @Test func runnerWritesTheSidecarBesideTheFileOnlyWhenOn() async throws {
        let item = try photo()
        for sidecar in [true, false] {
            let options = ExportOptions(longEdge: 1024, folder: "/out", sidecar: sidecar)
            let plan = ExportPlan(items: [.init(photoID: item.id, fileName: "IMG_0001.jpg",
                                                size: PixelSize(width: 1024, height: 683))], options: options)
            let writer = FakeJPEGWriter()
            let sidecars = SidecarLog()
            let summary = await ExportRunner.run(plan, photos: [item.id: item], exporter: FakeExporter(), writer: writer,
                                                 writeSidecar: { data, folder, name in await sidecars.add(folder, name, data) },
                                                 progress: { _ in })
            #expect(summary.message == "Exported 1 photo.")
            #expect(try await writer.existingNames(in: "/out") == ["IMG_0001.jpg"])
            let written = await sidecars.entries
            #expect(written.map(\.path) == (sidecar ? ["/out/IMG_0001.xmp"] : []))
            #expect(written.allSatisfy { String(data: $0.data, encoding: .utf8)?.contains("xmp:Rating=\"3\"") == true })
        }
    }
}

/// The sidecars a run wrote, by "folder/name".
private actor SidecarLog {
    private(set) var entries: [(path: String, data: Data)] = []
    func add(_ folder: String, _ name: String, _ data: Data) { entries.append((folder + "/" + name, data)) }
}
