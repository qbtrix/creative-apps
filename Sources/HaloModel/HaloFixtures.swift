// HaloFixtures.swift: the named fixture projects (blueprint section 2),
// built in code so journeys (`-HaloFixture <name>`), snapshots and budget
// tests share one copy. Every key value is a whole number, ids follow the
// app's own scheme ("comp-1", "comp-1-layer-3") and the id counters sit past
// the last one used, so an edit on a fixture never reuses an id.
// Linux-safe: no UI imports.

public enum HaloFixtures {
    /// Every fixture, in the order the blueprint lists them.
    public static let names = ["empty", "three-layers", "keyed", "parented", "two-comps", "reference", "crowd", "huge"]

    /// The frames between two keys in `huge`: every property keyed every
    /// `hugeKeySpacing` frames over 120 frames. Chosen once while writing
    /// FD-9 so the file encodes to at most 48 MiB (HaloFixturesTests checks
    /// it): at 2, 960,000 keys encode to 46,011,029 bytes (about 43.9 MiB).
    public static let hugeKeySpacing = 2

    /// The fixture called `name`, the first composition selected; nil for an
    /// unknown name.
    public static func project(_ name: String) -> HaloDocumentState? {
        switch name {
        case "empty": document([comp(1, "Comp 1", fps: 30, frames: 300)])
        case "three-layers": document([threeLayers(1)])
        case "keyed": document([keyed(1)])
        case "parented": document([parented(1)])
        case "two-comps": document([threeLayers(1), keyed(2, name: "Outro")])
        case "reference": document([reference(1)])
        case "crowd": document([crowd(1)])
        case "huge": document([huge(1)])
        default: nil
        }
    }

    static func document(_ comps: [HaloComposition]) -> HaloDocumentState {
        let layerNumbers = comps.flatMap(\.layers).compactMap { Int($0.id.split(separator: "-").last ?? "") }
        return HaloDocumentState(
            compositions: comps, selectedCompositionID: comps.first?.id,
            nextCompositionNumber: comps.count + 1, nextLayerNumber: (layerNumbers.max() ?? 0) + 1)
    }

    static func comp(_ n: Int, _ name: String, fps: Int, frames: Int, layers: [HaloLayer] = []) -> HaloComposition {
        HaloComposition(
            id: "comp-\(n)", name: name, width: 1920, height: 1080, framesPerSecond: fps, durationFrames: frames,
            layers: layers)
    }

    /// Layer `number` of composition `n`, spanning `span`.
    static func layer(
        _ n: Int, _ number: Int, _ name: String, _ kind: HaloLayerKind, _ span: Range<Int>, rect: HaloLayerRect? = nil
    ) -> HaloLayer {
        HaloLayer(
            id: "comp-\(n)-layer-\(number)", name: name, kind: kind, inFrame: span.lowerBound, outFrame: span.upperBound,
            color: kind.defaultColor, rect: rect)
    }

    static func keys(_ pairs: [(Int, Double)]) -> [HaloKeyframe] {
        pairs.map { HaloKeyframe(frame: $0.0, value: $0.1) }
    }

    /// "Intro": Title (text "Hello Halo", 24–72), Badge, Background, Rig, top first.
    static func threeLayers(_ n: Int) -> HaloComposition {
        var title = layer(n, 4, "Title", .text, 24..<72)
        title.text = HaloTextContent(string: "Hello Halo", fontSize: 96)
        let badge = layer(n, 3, "Badge", .shape, 0..<72, rect: HaloLayerRect(x: 0, y: 0, width: 240, height: 240))
        let background = layer(n, 2, "Background", .solid, 0..<72)
        let rig = layer(n, 1, "Rig", .null, 0..<72)
        return comp(n, "Intro", fps: 24, frames: 72, layers: [title, badge, background, rig])
    }

    /// "Bounce": Ball (x 160 at 0 and 960 at 24, opacity 0 at 0 and 1 at 12) over Floor.
    static func keyed(_ n: Int, name: String = "Bounce") -> HaloComposition {
        var ball = layer(n, 2, "Ball", .solid, 0..<48, rect: HaloLayerRect(x: 0, y: 0, width: 200, height: 200))
        ball.tracks["x"] = keys([(0, 160), (24, 960)])
        ball.tracks["opacity"] = keys([(0, 0), (12, 1)])
        let floor = layer(n, 1, "Floor", .solid, 0..<48, rect: HaloLayerRect(x: 0, y: 880, width: 1920, height: 200))
        return comp(n, name, fps: 24, frames: 48, layers: [ball, floor])
    }

    /// `keyed` with a "Rig" null on top (x 960 at 0 and 1160 at 47) that nothing follows.
    static func parented(_ n: Int) -> HaloComposition {
        var c = keyed(n)
        var rig = layer(n, 3, "Rig", .null, 0..<48)
        rig.tracks["x"] = keys([(0, 960), (47, 1160)])
        c.layers.insert(rig, at: 0)
        return c
    }

    /// 50 layers (solids, shapes, text) with every property keyed at 10
    /// frames: 4,000 keys.
    static func reference(_ n: Int) -> HaloComposition {
        let kinds: [HaloLayerKind] = [.solid, .shape, .text]
        let layers = (1...50).reversed().map { i in
            var l = layer(n, i, "\(kinds[i % 3].title) \(i)", kinds[i % 3], 0..<300,
                rect: HaloLayerRect(x: 0, y: 0, width: 200, height: 120))
            if l.kind == .text { l.text = HaloTextContent(string: "Line \(i)", fontSize: 48) }
            for p in HaloProperty.allCases {
                l.tracks[p.rawValue] = (0..<10).map { k in HaloKeyframe(frame: k * 30, value: wholeValue(p, i + k)) }
            }
            return l
        }
        return comp(n, "Reference", fps: 30, frames: 300, layers: layers)
    }

    /// 300 solids; the top 250 have x and y keyed at 10 frames: 5,000 keys.
    static func crowd(_ n: Int) -> HaloComposition {
        let layers = (1...300).reversed().map { i in
            var l = layer(n, i, "Solid \(i)", .solid, 0..<300, rect: HaloLayerRect(x: 0, y: 0, width: 100, height: 100))
            if i > 50 {
                for p in [HaloProperty.x, .y] {
                    l.tracks[p.rawValue] = (0..<10).map { k in HaloKeyframe(frame: k * 30, value: wholeValue(p, i + k)) }
                }
            }
            return l
        }
        return comp(n, "Crowd", fps: 30, frames: 300, layers: layers)
    }

    /// 2,000 solids with every property keyed every `hugeKeySpacing` frames
    /// over 120 frames.
    static func huge(_ n: Int) -> HaloComposition {
        let frames = Array(stride(from: 0, to: 120, by: max(1, hugeKeySpacing)))
        let layers = (1...2000).reversed().map { i in
            var l = layer(n, i, "Solid \(i)", .solid, 0..<120)
            for p in HaloProperty.allCases {
                l.tracks[p.rawValue] = frames.map { f in HaloKeyframe(frame: f, value: wholeValue(p, i + f)) }
            }
            return l
        }
        return comp(n, "Huge", fps: 30, frames: 120, layers: layers)
    }

    /// A whole number in `property`'s range that varies with `seed`.
    static func wholeValue(_ property: HaloProperty, _ seed: Int) -> Double {
        switch property {
        case .x, .anchorX: Double(seed % 1920)
        case .y, .anchorY: Double(seed % 1080)
        case .scaleX, .scaleY: Double(1 + seed % 2)
        case .rotation: Double(seed % 360)
        case .opacity: Double(seed % 2)
        }
    }
}
