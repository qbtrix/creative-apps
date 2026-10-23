// Live/PhotoStackXML.swift: the OpenRaster `stack.xml` LiveArchive writes for
// other readers (https://www.openraster.org/baseline/layer-stack-spec.html):
// one <layer> per pixel layer, top first, with its src, name, offset, opacity,
// visibility and composite-op, and a text layer's `afterglow:text`
// (PhotoTextLayer+ORA, the one attribute read back). Adjustment layers and
// masks have no OpenRaster word and live only in photo/document.json.
// Linux-safe. Names and paths are escaped by SuiteModel's XMLText.
import CoreRaster
import SuiteModel

enum PhotoStackXML {
    /// The spec version these elements follow.
    static let version = "0.0.6"

    /// `texts`: each text layer's `afterglow:text` value by its `src`, not yet escaped.
    static func stack(_ canvas: CanvasSize, _ layers: [LayerEntry], texts: [String: String] = [:]) -> String {
        var xml = #"<?xml version="1.0" encoding="UTF-8"?>"# + "\n"
        xml += #"<image version="\#(version)" w="\#(canvas.width)" h="\#(canvas.height)">"# + "\n<stack>\n"
        for layer in layers {
            guard let src = layer.src else { continue }
            xml += #"<layer name="\#(XMLText.escaped(layer.name))" src="\#(XMLText.escaped(src))" x="\#(layer.offset.x)""#
            xml += #" y="\#(layer.offset.y)" opacity="\#(layer.opacity)""#
            xml += #" visibility="\#(layer.visible ? "visible" : "hidden")" composite-op="\#(compositeOp(layer.blend))""#
            if let text = texts[src] { xml += #" \#(PhotoTextLayer.oraAttribute)="\#(XMLText.escaped(text))""# }
            xml += "/>\n"
        }
        return xml + "</stack>\n</image>\n"
    }

    /// The SVG compositing name: normal is "svg:src-over", colorDodge "svg:color-dodge".
    static func compositeOp(_ mode: BlendMode) -> String {
        guard mode != .normal else { return "svg:src-over" }
        var name = "svg:"
        for character in mode.rawValue {
            if character.isUppercase { name += "-" + character.lowercased() } else { name.append(character) }
        }
        return name
    }
}
