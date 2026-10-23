// ImportFidelitySVGTests.swift: the SVG half of the import fidelity gate. Each
// file Tests/import_fidelity/gen.py wrote must open through FlareCore's
// SVGImport with its top-level layers by name, its scene size, its text, and
// at each probe point the paint the SVG spec puts there (the top shape a hit
// test finds, its solid or gradient colour, within 0.02). Everything stays a
// vector path, so a 2x render is sharp. Content the importer can't hold must
// be named in its report (a probe lists the report entry that excuses it);
// content dropped or changed with no entry fails. A file with a known gap runs
// under withKnownIssue owned by its finding issue (manifest "gap"), so a fix
// flips it to an error until the gap is taken out of gen.py. Linux and macOS.
import FlareCore
import Foundation
import Testing

struct SVGCase: Decodable, Sendable, CustomTestStringConvertible {
    struct Probe: Decodable, Sendable { let x: Double, y: Double, rgba: [Double]?, excuse: String? }
    struct Text: Decodable, Sendable { let string: String, anchor: String?, weight: Int? }
    let file: String, what: String, layers: [String]
    let size: [Double]?, reported: [String]?, groups: [String]?, probes: [Probe]?, texts: [Text]?, gap: Int?
    var testDescription: String { file }
}

enum SVGCorpus {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("import_fidelity")
    static let cases: [SVGCase] = {
        struct Manifest: Decodable { let svg: [SVGCase] }
        let data = (try? Data(contentsOf: root.appendingPathComponent("manifest.json"))) ?? Data()
        return (try? JSONDecoder().decode(Manifest.self, from: data).svg) ?? []
    }()
}

@Suite struct ImportFidelitySVGTests {
    @Test func theCorpusIsThere() {
        #expect(SVGCorpus.cases.count >= 15, "run python3 Tests/import_fidelity/gen.py")
    }

    @Test(arguments: SVGCorpus.cases) func opensAsAuthored(_ c: SVGCase) throws {
        let data = try Data(contentsOf: SVGCorpus.root.appendingPathComponent(c.file))
        guard let gap = c.gap else { return try check(c, data) }
        try withKnownIssue("\(c.what): the SVG importer drops it without a report entry (finding #\(gap))") { try check(c, data) }
    }

    private func check(_ c: SVGCase, _ data: Data) throws {
        let (scene, report) = try SVGImport.scene(from: data, name: c.file)
        let reported = { (kind: String) in report.skipped.contains { $0.hasPrefix(kind + " (") } }
        #expect(scene.layers.map(\.name) == c.layers, "\(c.file): layers")
        if let size = c.size {
            #expect(abs(scene.width - size[0]) < 0.01 && abs(scene.height - size[1]) < 0.01, "\(c.file): size \(scene.width) x \(scene.height)")
        }
        for kind in c.reported ?? [] {
            #expect(reported(kind), "\(c.file): \(kind) isn't in the report \(report.skipped)")
        }
        for group in c.groups ?? [] {
            #expect(scene.layers.contains { $0.name == group } || reported("nested group"),
                    "\(c.file): group \(group) is flattened away and the report doesn't say so")
        }
        for p in c.probes ?? [] where !(p.excuse.map(reported) ?? false) {
            let got = Self.paint(at: Point(x: p.x, y: p.y), in: scene)
            let close = zip(got ?? [], p.rgba ?? []).allSatisfy { abs($0 - $1) < 0.02 } && (got == nil) == (p.rgba == nil)
            #expect(close, "\(c.file): at (\(p.x), \(p.y)) \(got.map { "\($0)" } ?? "nothing") for \(p.rgba.map { "\($0)" } ?? "nothing")")
        }
        let texts = scene.layers.flatMap(\.texts)
        for t in c.texts ?? [] {
            let shape = texts.first { $0.string == t.string }
            #expect(shape != nil, "\(c.file): text \"\(t.string)\" is missing")
            if let anchor = t.anchor {
                #expect(shape?.paragraph?.alignment.rawValue == anchor || reported("text-anchor"), "\(c.file): \"\(t.string)\" isn't \(anchor) aligned")
            }
            if let weight = t.weight {
                #expect(shape?.runs.contains { $0.weight == weight } == true || reported("font-weight"), "\(c.file): \"\(t.string)\" lost weight \(weight)")
            }
        }
        // No raster stand-in for vector art: every shape is a path, so it redraws sharp at 2x.
        #expect(scene.layers.flatMap(\.shapes).allSatisfy { $0.path != nil || !$0.points.isEmpty })
    }

    /// The paint on top at `p`: the last visible layer whose masks let it through, its last shape whose fill
    /// (non-zero) or stroke covers it, as straight RGBA; nil where nothing paints.
    static func paint(at p: Point, in scene: Scene) -> [Double]? {
        for layer in scene.layers.reversed() where layer.isVisible && inside(layer.masks, p) {
            for shape in layer.shapes.reversed() {
                if shape.contains(p, rule: .nonZero), let c = color(shape.fill, p), c[3] > 0 { return c }
                if let stroke = shape.stroke, stroke.color.a > 0, shape.hits(p, rule: .nonZero) {
                    return [stroke.color.r, stroke.color.g, stroke.color.b, stroke.color.a]
                }
            }
        }
        return nil
    }

    private static func inside(_ masks: [LayerMask], _ p: Point) -> Bool {
        let hit = { (m: LayerMask) in Shape(points: [], path: m.path).contains(p, rule: .nonZero) }
        let adds = masks.filter { $0.mode == .add }
        return (adds.isEmpty || adds.contains(where: hit)) && masks.filter { $0.mode == .intersect }.allSatisfy(hit)
    }

    private static func color(_ fill: Fill, _ p: Point) -> [Double]? {
        let t: Double, stops: [GradientStop]
        switch fill {
        case .solid(let c): return [c.r, c.g, c.b, c.a]
        case .linear(let s, let a, let b):
            let (dx, dy) = (b.x - a.x, b.y - a.y)
            t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(dx * dx + dy * dy, 1e-12)
            stops = s
        case .radial(let s, let center, let radius):
            t = ((p.x - center.x) * (p.x - center.x) + (p.y - center.y) * (p.y - center.y)).squareRoot() / radius
            stops = s
        }
        guard let first = stops.first, let last = stops.last else { return nil }
        let k = min(max(t, 0), 1)
        guard k > first.offset else { return [first.color.r, first.color.g, first.color.b, first.color.a] }
        guard let i = stops.firstIndex(where: { $0.offset >= k }) else { return [last.color.r, last.color.g, last.color.b, last.color.a] }
        let (a, b) = (stops[i - 1], stops[i])
        let f = b.offset > a.offset ? (k - a.offset) / (b.offset - a.offset) : 1
        let mix = { (x: Double, y: Double) in x + (y - x) * f }
        return [mix(a.color.r, b.color.r), mix(a.color.g, b.color.g), mix(a.color.b, b.color.b), mix(a.color.a, b.color.a)]
    }
}
