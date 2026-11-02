// ExportScan.swift: the warnings every export carries, shared by the fake and live exporters (docs/blueprints/flare.md,
// 6.2 and 6.3). What a format drops gets a named warning, never a silent drop: text in Lottie and PNG (core's SVG
// writes it; Lottie can't, and PNG frames draw no glyphs), symbol animation in Lottie (its instances hold their first
// frame; SVG and PNG play them), state machines everywhere, and the background color in Lottie. Text counts every
// layer holding one, hidden or not, in the scene or a symbol its instances reach. Masks and mattes need no warning:
// SVG and PNG (FlareRaster) both draw them. `maskedLayers` feeds the stage's own "Masks not shown" pill.
import FlareCore

public enum ExportScan {
    /// The warnings for exporting `options.sceneID` as `options.format`, in a fixed order; empty for a missing scene.
    public static func warnings(_ document: Document, options: ExportOptions) -> [String] {
        guard let scene = document.scenes.first(where: { $0.id == options.sceneID }) else { return [] }
        var warnings: [String] = []
        let texts = textLayers(scene.layers, document.symbols, seen: [])
        if texts > 0, options.format != .svgFrame { warnings.append("Text isn't exported yet (\(count(texts, "layer"))).") }
        let instances = scene.layers.flatMap(\.instances).filter { isAnimated($0, document.symbols) }.count
        if instances > 0, options.format == .lottie { warnings.append("Symbol animation exports as its first frame (\(count(instances, "instance"))).") }
        let machines = document.stateMachines.count
        if machines > 0 { warnings.append("Interactions aren't exported (\(count(machines, "machine"))).") }
        if options.format == .lottie, !options.transparentBackground {
            warnings.append("Background color isn't part of Lottie.")
        }
        return warnings
    }

    /// The number of layers holding text among `scene`'s layers and the symbols its instances reach.
    public static func textLayers(in document: Document, sceneID: String) -> Int {
        document.scenes.first { $0.id == sceneID }.map { textLayers($0.layers, document.symbols, seen: []) } ?? 0
    }

    /// `document` with every text removed, scene and symbol layers alike, so Lottie and video can write the rest.
    public static func withoutText(_ document: Document) -> Document {
        func strip(_ layers: [Layer]) -> [Layer] { layers.map { var layer = $0; layer.texts = []; return layer } }
        var clean = document
        for i in clean.scenes.indices { clean.scenes[i].layers = strip(clean.scenes[i].layers) }
        for i in clean.symbols.indices { clean.symbols[i].layers = strip(clean.symbols[i].layers) }
        return clean
    }

    /// Layers with a mask or a track matte among `layers` and the symbols their instances reach: what the stage
    /// and PNG frames can't draw yet.
    public static func maskedLayers(_ layers: [Layer], _ symbols: [Symbol]) -> Int {
        countLayers(layers, symbols, seen: []) { !$0.masks.isEmpty || $0.matte != nil }
    }

    private static func textLayers(_ layers: [Layer], _ symbols: [Symbol], seen: Set<String>) -> Int {
        countLayers(layers, symbols, seen: seen) { !$0.texts.isEmpty }
    }

    /// Layers matching `holds` among `layers` and the symbols their instances reach; `seen` stops a symbol cycle.
    private static func countLayers(_ layers: [Layer], _ symbols: [Symbol], seen: Set<String>,
                                    _ holds: (Layer) -> Bool) -> Int {
        var total = layers.filter(holds).count
        var reached = seen
        for id in layers.flatMap(\.instances).map(\.symbolID) where !reached.contains(id) {
            reached.insert(id)
            guard let symbol = symbols.first(where: { $0.id == id }) else { continue }
            total += countLayers(symbol.layers, symbols, seen: reached, holds)
        }
        return total
    }

    /// True when the instance plays its symbol and some layer of it has a track with more than one key.
    private static func isAnimated(_ instance: Instance, _ symbols: [Symbol]) -> Bool {
        guard instance.loop != .singleFrame, let symbol = symbols.first(where: { $0.id == instance.symbolID }) else { return false }
        return symbol.layers.contains { $0.tracks.values.contains { $0.count > 1 } }
    }

    private static func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }
}
