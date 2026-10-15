// Live/PhotoStackXML.swift: the OpenRaster `stack.xml` LiveArchive writes for
// other readers (https://www.openraster.org/baseline/layer-stack-spec.html):
// one <layer> per pixel layer, top first, with its src, name, offset, opacity,
// visibility and composite-op. Adjustment layers and masks have no OpenRaster
// word and live only in photo/document.json. Written, never parsed back.
// Linux-safe.
import CoreRaster

enum PhotoStackXML {
    /// The spec version these elements follow.
    static let version = "0.0.6"

    static func stack(_ canvas: CanvasSize, _ layers: [LayerEntry]) -> String {
        var xml = #"<?xml version="1.0" encoding="UTF-8"?>"# + "\n"
        xml += #"<image version="\#(version)" w="\#(canvas.width)" h="\#(canvas.height)">"# + "\n<stack>\n"
        for layer in layers {
            guard let src = layer.src else { continue }
            xml += #"<layer name="\#(escaped(layer.name))" src="\#(escaped(src))" x="\#(layer.offset.x)""#
            xml += #" y="\#(layer.offset.y)" opacity="\#(layer.opacity)""#
            xml += #" visibility="\#(layer.visible ? "visible" : "hidden")" composite-op="\#(compositeOp(layer.blend))"/>"#
            xml += "\n"
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

    /// `text` safe inside a double-quoted XML attribute.
    static func escaped(_ text: String) -> String {
        var out = ""
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(character)
            }
        }
        return out
    }
}
