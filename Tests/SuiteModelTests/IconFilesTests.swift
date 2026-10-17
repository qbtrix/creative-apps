// IconFilesTests.swift: every CFBundleIconFile named in the six plists in
// Bundle/Info/ has Bundle/Icons/<name>.png, 1024 x 1024 read from the PNG
// header (bundle packet BU-5c), and <name>-<px>.png for each smaller .icns
// size. Each PNG is the render of its source, Bundle/Marks/<name>.svg:
// Bundle/Icons/marks.json, which scripts/render-marks writes, records an
// FNV-1a 64 digest of the SVG and of every PNG, so an SVG edited without a
// rerender, or a PNG edited by hand, fails here. Files are read by path from
// #filePath.
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

    /// The .icns sizes below 1024, each rendered to Bundle/Icons/<app>-<px>.png.
    static let smallerSizes = [16, 32, 64, 128, 256, 512]

    /// FNV-1a 64 as 16 lowercase hex digits, the digest scripts/render-marks records.
    static func fnv(_ bytes: [UInt8]) -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in bytes {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }

    static func bytes(_ path: String) throws -> [UInt8] {
        [UInt8](try Data(contentsOf: root.appendingPathComponent(path)))
    }

    /// marks.json's entry for `app`: its SVG's digest and its PNGs' digests by size.
    static func recorded(_ app: String) throws -> (svg: String, png: [String: String]) {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Bundle/Icons/marks.json")))
        let icons = try #require((json as? [String: Any])?["icons"] as? [String: Any])
        let entry = try #require(icons[app] as? [String: Any], "marks.json has no \(app)")
        return (try #require(entry["svg"] as? String), try #require(entry["png"] as? [String: String]))
    }

    @Test(arguments: apps) func everySizeIsTheRenderOfItsSVG(_ app: String) throws {
        let recorded = try Self.recorded(app)
        #expect(Self.fnv(try Self.bytes("Bundle/Marks/\(app).svg")) == recorded.svg,
                "Bundle/Marks/\(app).svg changed since its PNGs were rendered: run scripts/render-marks")
        for size in Self.smallerSizes + [1024] {
            let file = size == 1024 ? "\(app).png" : "\(app)-\(size).png"
            let bytes = try Self.bytes("Bundle/Icons/\(file)")
            #expect(Self.fnv(bytes) == recorded.png[String(size)], "Bundle/Icons/\(file) is not the render marks.json records")
            let found = try #require(Self.pngSize(bytes), "Bundle/Icons/\(file) is not a PNG")
            #expect(found.width == size && found.height == size, "Bundle/Icons/\(file) is \(found.width) x \(found.height)")
        }
    }

    @Test func theDigestIsFNV1a64() {
        #expect(Self.fnv([]) == "cbf29ce484222325")
        #expect(Self.fnv(Array("a".utf8)) == "af63dc4c8601ec8c")
        #expect(Self.fnv(Array("foobar".utf8)) == "85944171f73967e8")
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
