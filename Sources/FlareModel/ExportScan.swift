// ExportScan.swift: the warnings every export carries, shared by the fake and live exporters (docs/blueprints/flare.md,
// 6.2 and 6.3). v1's exporters can't write text, symbol animation (instances flatten to their first frame), state
// machines or, in Lottie, the background color, so each one present gets a named warning: never a silent drop. PNG
// frames are the stage's picture, which has no masks or mattes yet, so a PNG export names those layers too. Text and
// masks count every layer holding one, hidden or not, in the scene or a symbol its instances reach.
import FlareCore

public enum ExportScan {
    /// The warnings for exporting `options.sceneID` as `options.format`, in a fixed order; empty for a missing scene.
    public static func warnings(_ document: Document, options: ExportOptions) -> [String] {
        guard let scene = document.scenes.first(where: { $0.id == options.sceneID }) else { return [] }
        var warnings: [String] = []
        let texts = textLayers(scene.layers, document.symbols, seen: [])
        if texts > 0 { warnings.append("Text isn't exported yet (\(count(texts, "layer"))).") }
        let instances = scene.layers.flatMap(\.instances).filter { isAnimated($0, document.symbols) }.count
        if instances > 0 { warnings.append("Symbol animation exports as its first frame (\(count(instances, "instance"))).") }
        let machines = document.stateMachines.count
        if machines > 0 { warnings.append("Interactions aren't exported (\(count(machines, "machine"))).") }
        let masked = maskedLayers(scene.layers, document.symbols)
        if options.format == .pngSequence, masked > 0 {
            warnings.append("Masks and mattes aren't drawn in PNG yet (\(count(masked, "layer"))).")
        }
        if options.format == .lottie, !options.transparentBackground {
            warnings.append("Background color isn't part of Lottie.")
        }
        return warnings
    }

    /// `document` with every text removed, scene and symbol layers alike, so v1's exporters can write the rest.
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
