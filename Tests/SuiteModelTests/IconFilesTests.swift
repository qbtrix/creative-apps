// IconFilesTests.swift: every CFBundleIconFile named in the six plists in
// Bundle/Info/ has Bundle/Icons/<name>.png, 1024 x 1024 read from the PNG
// header (bundle packet BU-5c). Files are read by path from #filePath.
import Foundation
import Testing

@Suite struct IconFilesTests {
    static let apps = ["AfterGlow", "Flare", "Design", "Photo", "Library", "Halo"]

    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    static func iconName(_ app: String) throws -> String {
        let data = try Data(contentsOf: root.appendingPathComponent("Bundle/Info/\(app).plist"))
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)
        let plist = try #require(value as? [String: Any])
        return try #require(plist["CFBundleIconFile"] as? String)
    }

    /// Width and height from a PNG's IHDR chunk, or nil when the bytes are not a PNG.
    static func pngSize(_ bytes: [UInt8]) -> (width: Int, height: Int)? {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard bytes.count >= 24, Array(bytes[0..<8]) == signature,
              Array(bytes[12..<16]) == Array("IHDR".utf8) else { return nil }
        func be32(_ at: Int) -> Int {
            bytes[at..<(at + 4)].reduce(0) { ($0 << 8) | Int($1) }
        }
        return (be32(16), be32(20))
    }

    static func header(width: Int, height: Int) -> [UInt8] {
        func be32(_ v: Int) -> [UInt8] { [24, 16, 8, 0].map { UInt8((v >> $0) & 0xFF) } }
        return [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] + be32(13) + Array("IHDR".utf8)
            + be32(width) + be32(height) + [8, 6, 0, 0, 0]
    }

    @Test(arguments: apps) func iconExistsAt1024(_ app: String) throws {
        let name = try Self.iconName(app)
        #expect(name == app)
        let file = name.hasSuffix(".png") ? name : name + ".png"
        let url = Self.root.appendingPathComponent("Bundle/Icons/\(file)")
        #expect(FileManager.default.fileExists(atPath: url.path), "missing Bundle/Icons/\(file)")
        let bytes = [UInt8](try Data(contentsOf: url))
        let size = try #require(Self.pngSize(bytes), "Bundle/Icons/\(file) is not a PNG")
        #expect(size.width == 1024)
        #expect(size.height == 1024)
    }

    @Test func headerReaderRejectsWrongSizeAndNonPNG() {
        let ok = Self.pngSize(Self.header(width: 1024, height: 1024))
        #expect(ok?.width == 1024 && ok?.height == 1024)
        let small = Self.pngSize(Self.header(width: 512, height: 1024))
        #expect(small?.width == 512)
        #expect(Self.pngSize(Array("not a png at all, just text".utf8)) == nil)
        #expect(Self.pngSize([0x89, 0x50]) == nil)
    }
}
