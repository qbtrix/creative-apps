// ImportFidelityPSDTests.swift: the PSD half of the import fidelity gate. Each
// file Tests/import_fidelity/gen.py wrote must open through CoreRaster's
// PSD.read with every layer and group, by name, kind, visibility, blend mode,
// opacity, clipping and mask, and the layer tree flattened here must match
// the merged image the authoring app stored (8-bit, within 2). A file the
// reader can't hold must throw a reason naming what it is; content dropped
// with no reason fails. A file with a known gap runs under withKnownIssue
// owned by its finding issue (manifest "gap"), so a fix flips it to an error
// until the gap is taken out of gen.py. Runs on Linux and macOS.
import CoreRaster
import Foundation
import Testing

struct PSDCase: Decodable, Sendable, CustomTestStringConvertible {
    let file: String, what: String, width: Int, height: Int, bits: Int
    let refuse: String?, tree: [PSDNode]?, gap: Int?
    var testDescription: String { file }
}

struct PSDNode: Decodable, Sendable {
    let name: String, kind: String, hidden: Bool, blend: String?
    let opacity: Int?, clip: Bool?, mask: Bool?, children: [PSDNode]?
}

enum PSDCorpus {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("import_fidelity")
    static let cases: [PSDCase] = {
        struct Manifest: Decodable { let psd: [PSDCase] }
        let data = (try? Data(contentsOf: root.appendingPathComponent("manifest.json"))) ?? Data()
        return (try? JSONDecoder().decode(Manifest.self, from: data).psd) ?? []
    }()
}

@Suite struct ImportFidelityPSDTests {
    @Test func theCorpusIsThere() {
        #expect(PSDCorpus.cases.count >= 15, "run python3 Tests/import_fidelity/gen.py")
    }

    @Test(arguments: PSDCorpus.cases) func opensAsAuthored(_ c: PSDCase) throws {
        let data = try Data(contentsOf: PSDCorpus.root.appendingPathComponent(c.file))
        if let refuse = c.refuse {
            do {
                _ = try PSD.read(data)
                Issue.record("\(c.file) opened; it should refuse with a reason naming \"\(refuse)\"")
            } catch {
                #expect("\(error)".contains(refuse), "\(c.file) refused with \(error), not a reason naming \"\(refuse)\"")
            }
            return
        }
        guard let gap = c.gap else { return try check(c, data) }
        try withKnownIssue("\(c.what): the PSD reader drops it without a reason (finding #\(gap))") { try check(c, data) }
    }

    private func check(_ c: PSDCase, _ data: Data) throws {
        let image = try PSD.read(data)
        #expect(image.width == c.width && image.height == c.height && image.bitsPerChannel == c.bits)
        compare(image.nodes, c.tree ?? [], at: c.file)
        let want = try #require(image.composite, "\(c.file) has no merged image").rgba8()
        let got = try Self.flatten(image).rgba8()
        var bad = 0, first = ""
        for i in stride(from: 0, to: want.count, by: 4) where (0..<3).contains(where: { abs(Int(want[i + $0]) - Int(got[i + $0])) > 2 }) {
            if bad == 0 {
                first = "first at (\(i / 4 % c.width), \(i / 4 / c.width)): \(got[i..<i + 3].map { $0 }) for \(want[i..<i + 3].map { $0 })"
            }
            bad += 1
        }
        #expect(bad == 0, "\(c.file): \(bad) of \(want.count / 4) pixels differ from the authored picture; \(first)")
    }

    private func compare(_ nodes: [LayerNode], _ expected: [PSDNode], at path: String) {
        #expect(nodes.count == expected.count, "\(path): \(nodes.count) layers open, the file has \(expected.count)")
        for (node, e) in zip(nodes, expected) {
            switch node {
            case .pixels(let l):
                #expect(e.kind == "pixels", "\(path)/\(e.name): the file's \(e.kind) layer opens as plain pixels")
                #expect(l.name == e.name && l.isHidden == e.hidden, "\(path)/\(e.name): opened as \(l.name), hidden \(l.isHidden)")
                #expect("\(l.blendMode)" == e.blend, "\(path)/\(e.name): blend \(e.blend ?? "-") opens as \(l.blendMode)")
                #expect(Int((l.opacity * 255).rounded()) == e.opacity && l.clipsToBelow == e.clip && (l.mask != nil) == e.mask,
                        "\(path)/\(e.name): opacity, clipping or mask lost")
            case .group(let g):
                #expect(e.kind == "group" && g.name == e.name && g.isHidden == e.hidden, "\(path)/\(e.name): opened as group \(g.name)")
                #expect(g.blendMode.map { "\($0)" } == e.blend, "\(path)/\(e.name): group blend lost")
                compare(g.children, e.children ?? [], at: "\(path)/\(e.name)")
            }
        }
    }

    /// The tree flattened onto opaque white, the way the authoring app matted the merged image.
    static func flatten(_ image: LayeredImage) throws -> PixelBuffer {
        var canvas = try PixelBuffer(width: image.width, height: image.height, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        try draw(image.nodes, onto: &canvas)
        return canvas
    }

    private static func draw(_ nodes: [LayerNode], onto canvas: inout PixelBuffer) throws {
        var base: PixelLayer?
        for node in nodes {
            switch node {
            case .group(let g):
                base = nil
                guard !g.isHidden else { continue }
                guard let mode = g.blendMode else { try draw(g.children, onto: &canvas); continue }
                var layer = try PixelBuffer(width: canvas.width, height: canvas.height)
                try draw(g.children, onto: &layer)
                try canvas.composite(layer, x: 0, y: 0, mode: mode, opacity: g.opacity)
            case .pixels(let l):
                if !l.clipsToBelow { base = l }
                guard !l.isHidden else { continue }
                try canvas.composite(try covered(l, clippedTo: l.clipsToBelow ? base : nil), x: l.x, y: l.y,
                                     mode: l.blendMode, opacity: l.opacity)
            }
        }
    }

    /// The layer's pixels times its mask's coverage and, when clipped, the alpha under it.
    private static func covered(_ l: PixelLayer, clippedTo base: PixelLayer?) throws -> PixelBuffer {
        guard l.mask.map({ !$0.isDisabled }) == true || base != nil else { return l.pixels }
        var out = l.pixels
        for y in 0..<out.height {
            for x in 0..<out.width {
                let k = try coverage(l.mask, l.x + x, l.y + y) * (try base.map { try alpha($0, l.x + x, l.y + y) } ?? 1)
                let p = try out.pixel(x: x, y: y)
                try out.setPixel(x: x, y: y, RGBA(r: p.r * k, g: p.g * k, b: p.b * k, a: p.a * k))
            }
        }
        return out
    }

    private static func coverage(_ m: PlacedMask?, _ x: Int, _ y: Int) throws -> Float {
        guard let m, !m.isDisabled else { return 1 }
        let (mx, my) = (x - m.x, y - m.y)
        guard mx >= 0, my >= 0, mx < m.mask.width, my < m.mask.height else { return m.defaultCoverage }
        return try m.mask.coverage(x: mx, y: my)
    }

    private static func alpha(_ l: PixelLayer, _ x: Int, _ y: Int) throws -> Float {
        let (lx, ly) = (x - l.x, y - l.y)
        guard lx >= 0, ly >= 0, lx < l.pixels.width, ly < l.pixels.height else { return 0 }
        return try l.pixels.pixel(x: lx, y: ly).a * coverage(l.mask, x, y)
    }
}
