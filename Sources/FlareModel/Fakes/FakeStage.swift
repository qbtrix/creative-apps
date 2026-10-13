// FakeStage.swift: StageRendering by hand (docs/blueprints/flare.md, 6.3). Visible layers bottom first, each
// placed by `Layer.placement(at:)`: its shapes, then its instances one level deep (each instance's visible
// symbol layers at `Instance.resolve`'s frame, their own instances skipped), then its texts, which are listed
// with an empty path and counted in `hiddenTextCount`. With `unavailable` set, the list is empty.
import FlareCore

public struct FakeStage: StageRendering {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    public func drawList(_ document: Document, sceneID: String, frame: Int,
                         editing symbolID: String?) -> StageDrawList {
        guard unavailable == nil, let scene = document.scenes.first(where: { $0.id == sceneID }) else {
            return StageDrawList(width: 0, height: 0, background: .white, items: [])
        }
        let owner: LayerOwner = symbolID.map { .symbol($0) } ?? .scene(sceneID)
        var list = StageDrawList(width: scene.width, height: scene.height, background: scene.background, items: [])
        for layer in document.layers(of: owner) ?? [] where layer.isVisible {
            let placed = layer.placement(at: Double(frame))
            let matrix = placed.transform.matrix
            func item(_ kind: StageAddress.Item) -> StageAddress { StageAddress(owner: owner, layerID: layer.id, item: kind) }
            for (i, shape) in layer.shapes.enumerated() {
                list.items.append(StageItem(address: item(.shape(i)), path: shape.outline, fill: shape.fill,
                                            stroke: shape.stroke, transform: matrix, opacity: placed.opacity))
            }
            for (i, instance) in layer.instances.enumerated() {
                guard let (symbol, inner) = instance.resolve(in: document.symbols, frame: Double(frame),
                                                             path: symbolID.map { [$0] } ?? []) else { continue }
                let host = matrix * instance.transform.matrix
                for child in symbol.layers where child.isVisible {
                    let p = child.placement(at: inner)
                    let m = host * p.transform.matrix, opacity = placed.opacity * p.opacity
                    for shape in child.shapes {
                        list.items.append(StageItem(address: item(.instance(i)), path: shape.outline, fill: shape.fill,
                                                    stroke: shape.stroke, transform: m, opacity: opacity))
                    }
                    for text in child.texts {
                        list.items.append(Self.text(text, item(.instance(i)), m, opacity))
                    }
                    list.hiddenTextCount += child.texts.count
                }
            }
            for (i, text) in layer.texts.enumerated() {
                list.items.append(Self.text(text, item(.text(i)), matrix, placed.opacity))
            }
            list.hiddenTextCount += layer.texts.count
        }
        return list
    }

    /// A text item: listed so counts see it, never drawn (an empty path) in v1.
    private static func text(_ text: TextShape, _ address: StageAddress, _ matrix: Matrix, _ opacity: Double) -> StageItem {
        StageItem(address: address, path: FlarePath(), fill: text.fill, stroke: nil,
                  transform: matrix, opacity: opacity, isText: true)
    }
}
