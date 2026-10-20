// ExportOptionsTests.swift: the suite's export options, rules and format list (export-pack XP-1, XP-6).
// The values round-trip, the schema is closed, Export/ imports only Foundation,
// and the XP-6 rows check the bodies: exact pixels, refusals, the dropped tags
// and the JSON schema. KJ-export is the rules' Linux walk.
import Foundation
import Testing
import SuiteKernel

@Suite struct ExportOptionsTests {
    /// The artwork every row exports: a 500 × 625 artboard (4:5).
    static let artboard = (width: 500, height: 625)

    @Test func valuesRoundTripAndTitles() throws {
        let options = SuiteExportOptions(format: "jpeg", size: .pixels(width: 1080, height: 1350), quality: 0.8,
                                    metadata: .noLocation, alpha: false, fps: nil, loop: false)
        #expect(try JSONDecoder().decode(SuiteExportOptions.self, from: JSONEncoder().encode(options)) == options)
        #expect(ExportMetadata.allCases.map(\.title) == ["All", "All but location", "None"])
        #expect(ExportMetadata.allCases.map(\.rawValue) == ["all", "noLocation", "none"])
        #expect(ExportRules.maxSide == 16_384)
        guard case .pixels(_, _, let stretch) = SuiteExportSize.pixels(width: 1, height: 1) else { return }
        #expect(!stretch)
    }

    @Test func schemaIsClosedAndNamesEveryOption() {
        guard case .object(let fields) = SuiteExportOptions.schema.json, case .object(let properties)? = fields["properties"] else {
            Issue.record("the schema is not an object with properties")
            return
        }
        #expect(Set(properties.keys) == ["format", "size", "quality", "metadata", "alpha", "fps", "loop"])
        #expect(fields["required"] == .array([]))
        #expect(!SuiteExportOptions.schema.validate(.object(["colour": .string("red")])).isEmpty)
        #expect(SuiteExportOptions.schema.validate(.object(["size": .object(["pixels": .array([.number(1080), .number(1350)])])])).isEmpty)
    }

    @Test func exportImportsOnlyFoundation() throws {
        let root = KernelShapeTests.kernelSources
        let files = try KernelShapeTests.swiftFiles(under: root).filter { $0.hasPrefix("Export/") }
        #expect(files.contains("Export/ExportOptions.swift"))
        let other = try Regex(#"^\s*(@testable\s+)?import\s+(?!(Foundation|FoundationEssentials)\b)"#)
        for file in files {
            let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(separator: "\n") where line.contains(other) { Issue.record("\(file): \(line)") }
        }
    }

    // MARK: XP-6 rows (bodies)

    @Test func pixelsAreExact() throws {
        let exact = try ExportRules.pixels(of: Self.artboard, .pixels(width: 1080, height: 1350), evenSize: false)
        #expect(exact == (1080, 1350))
        let doubled = try ExportRules.pixels(of: Self.artboard, .scale(2), evenSize: false)
        #expect(doubled == (1000, 1250))
        let half = try ExportRules.pixels(of: (501, 625), .scale(0.5), evenSize: false)
        #expect(half == (251, 313))
        let stretched = try ExportRules.pixels(of: Self.artboard, .pixels(width: 1080, height: 1351, stretch: true), evenSize: false)
        #expect(stretched == (1080, 1351))
    }

    @Test func longEdgeRoundsTheShortSide() throws {
        let tall = try ExportRules.pixels(of: Self.artboard, .longEdge(2048), evenSize: false)
        #expect(tall == (1638, 2048))
        // 2047 × 4 / 5 = 1637.6: rounding gives 1638, flooring would give 1637.
        let rounded = try ExportRules.pixels(of: Self.artboard, .longEdge(2047), evenSize: false)
        #expect(rounded == (1638, 2047))
        let wide = try ExportRules.pixels(of: (1250, 1000), .longEdge(2047), evenSize: false)
        #expect(wide == (2047, 1638))
    }

    @Test func aShapeThatDoesNotKeepTheRatioIsRefused() {
        #expect(throws: ExportOptionRefusal.invalid(
            "1080 × 1351 doesn't keep the artwork's 4:5 shape. Unlock the ratio to stretch.")) {
            try ExportRules.pixels(of: Self.artboard, .pixels(width: 1080, height: 1351), evenSize: false)
        }
        let options = SuiteExportOptions(format: "jpeg", size: .pixels(width: 1080, height: 1351))
        #expect(ExportRules.refusal(options, source: Self.artboard, formats: ExportFormats.all)
                == "1080 × 1351 doesn't keep the artwork's 4:5 shape. Unlock the ratio to stretch.")
    }

    @Test func evenSizesRoundDownAndLimitsHold() throws {
        let h264 = try #require(ExportFormats.spec("mp4"))
        #expect(h264.needsEvenSize && h264.name == "H.264")
        let even = try ExportRules.pixels(of: (1081, 607), .scale(1), evenSize: h264.needsEvenSize)
        #expect(even == (1080, 606))
        let odd = try ExportRules.pixels(of: (1081, 607), .scale(1), evenSize: false)
        #expect(odd == (1081, 607))
        let tiny = try ExportRules.pixels(of: (1, 1), .scale(1), evenSize: true)
        #expect(tiny == (2, 2))
        #expect(throws: ExportOptionRefusal.self) {
            try ExportRules.pixels(of: Self.artboard, .pixels(width: 20_000, height: 25_000), evenSize: false)
        }
        #expect(throws: ExportOptionRefusal.self) { try ExportRules.pixels(of: Self.artboard, .scale(0), evenSize: false) }
        #expect(throws: ExportOptionRefusal.self) { try ExportRules.pixels(of: Self.artboard, .longEdge(0), evenSize: false) }
    }

    @Test func noLocationDropsGPSAndKeepsTheDate() {
        let none = ExportRules.dropped(.all)
        #expect(none.properties.isEmpty && none.xmp.isEmpty)
        let private_ = ExportRules.dropped(.noLocation)
        #expect(Self.drops(private_.properties, "{GPS}") && Self.drops(private_.properties, "{GPS}.Latitude"))
        #expect(Self.drops(private_.properties, "{Exif}.BodySerialNumber") && Self.drops(private_.properties, "{MakerApple}"))
        #expect(!Self.drops(private_.properties, "{Exif}.DateTimeOriginal") && !Self.drops(private_.properties, "{TIFF}.Orientation"))
        #expect(!Self.drops(private_.properties, "{TIFF}.Copyright"))
        #expect(private_.xmp.contains("exif:GPSLatitude") && !private_.xmp.contains("xmp:CreateDate"))
        let bare = ExportRules.dropped(.none)
        #expect(bare.properties.isSuperset(of: private_.properties) && bare.xmp.isSuperset(of: private_.xmp))
        #expect(Self.drops(bare.properties, "{Exif}.DateTimeOriginal") && Self.drops(bare.properties, "{TIFF}.Copyright"))
        #expect(!Self.drops(bare.properties, "{TIFF}.Orientation") && bare.xmp.contains("xmp:CreateDate"))
    }

    @Test func theFormatListSaysWhatEachCarries() throws {
        #expect(ExportFormats.all.map(\.id)
                == ["png", "jpeg", "heic", "tiff", "svg", "pdf", "mp4", "mp4-hevc", "mov-prores", "gif", "apng"])
        let png = try #require(ExportFormats.spec("png")), svg = try #require(ExportFormats.spec("svg"))
        #expect(!png.hasQuality && png.carriesMetadata && png.keepsAlpha && png.kind == .still)
        #expect(svg.kind == .vector && !svg.carriesMetadata)
        #expect(ExportFormats.spec("mov-prores")?.keepsAlpha == true && ExportFormats.spec("jpeg")?.hasQuality == true)
        #expect(ExportFormats.spec("webp") == nil)
    }

    @Test func refusalsSayWhy() {
        let ok = SuiteExportOptions(format: "png", size: .scale(2))
        #expect(ExportRules.refusal(ok, source: Self.artboard, formats: ExportFormats.all) == nil)
        let alpha = SuiteExportOptions(format: "mp4", size: .scale(1), alpha: true)
        #expect(ExportRules.refusal(alpha, source: Self.artboard, formats: ExportFormats.all)
                == "H.264 can't keep transparency. Choose ProRes 4444.")
        let quality = SuiteExportOptions(format: "jpeg", quality: 1.5)
        #expect(ExportRules.refusal(quality, source: Self.artboard, formats: ExportFormats.all) != nil)
        let unknown = SuiteExportOptions(format: "webp")
        #expect(ExportRules.refusal(unknown, source: Self.artboard, formats: ExportFormats.all) != nil)
    }

    @Test func jsonReadsEachKeyAndRefusesUnknownOnes() throws {
        let defaults = SuiteExportOptions(format: "png")
        let size = try SuiteExportOptions(json: Self.json(#"{"format":"jpeg","size":{"pixels":[1080,1350]},"metadata":"noLocation"}"#),
                                     defaults: defaults)
        #expect(size == SuiteExportOptions(format: "jpeg", size: .pixels(width: 1080, height: 1350), metadata: .noLocation))
        let long = try SuiteExportOptions(json: Self.json(#"{"size":{"longEdge":2048},"quality":0.5,"fps":24,"loop":true}"#), defaults: defaults)
        #expect(long.size == .longEdge(2048) && long.quality == 0.5 && long.fps == 24 && long.loop && long.format == "png")
        let stretch = try SuiteExportOptions(json: Self.json(#"{"size":{"pixels":[10,20],"stretch":true},"alpha":true}"#), defaults: defaults)
        #expect(stretch.size == .pixels(width: 10, height: 20, stretch: true) && stretch.alpha)
        #expect(try SuiteExportOptions(json: .null, defaults: defaults) == defaults)
        #expect(throws: ExportOptionRefusal.self) { try SuiteExportOptions(json: Self.json(#"{"colour":"red"}"#), defaults: defaults) }
        #expect(throws: ExportOptionRefusal.self) {
            try SuiteExportOptions(json: Self.json(#"{"size":{"scale":2,"longEdge":10}}"#), defaults: defaults)
        }
    }

    /// True when `drops` names `path` or the dictionary it sits in (`{GPS}` drops `{GPS}.Latitude`).
    static func drops(_ drops: Set<String>, _ path: String) -> Bool {
        drops.contains(path) || path.split(separator: ".").first.map { drops.contains(String($0)) } == true
    }

    static func json(_ text: String) throws -> JSONValue { try JSONValue(json: Data(text.utf8)) }
}
