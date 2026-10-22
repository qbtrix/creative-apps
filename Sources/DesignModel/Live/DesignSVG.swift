// Live/DesignSVG.swift: the SVG text of Design nodes, what File > Export writes
// for the SVG format (LiveExport.svg and DesignWorkspace.exportSVG call it).
// Design's own drawing, which no shared module has. Linux-safe: text only.
//
// The rules come from the W3C SVG 2 recommendation only (clean-room): the
// outermost <svg> with `viewBox` and `width`/`height`, basic shapes (<rect>,
// <ellipse>), <text> with `text-anchor`, <g> with `opacity`, and <clipPath>
// referenced by `clip-path="url(#…)"`. One element per visible layer in paint
// order (a node, then its children); a hidden node drops its whole subtree.
// Coordinates are page points minus the box's origin. An attribute whose value
// is the SVG default (opacity 1, no stroke, stroke-width 1, rx 0, font-weight
// 400, text-anchor start) is left out. Text and attribute values are escaped
// by SuiteModel's XMLText, the suite's one XML escaper.
// Each element sits on its own line, indented two spaces per depth. A gradient
// (gradient-fill DG-5) is a <linearGradient> or <radialGradient> in a <defs>
// just before its layer, written by SuiteKernel's GradientSVG with its points in
// the layer's frame (userSpaceOnUse), and the layer fills with `url(#g-<id>)`.
import SuiteKernel
import SuiteModel

/// The SVG text of nodes inside a box. One element per visible layer in paint order; the box is
/// the viewBox and coordinates are relative to its origin.
enum DesignSVG {
    static func document(_ nodes: [DesignNode], box: DesignRect, clip: Bool) -> String {
        let (w, h) = (number(box.width), number(box.height))
        var lines = ["<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(w) \(h)\" width=\"\(w)\" height=\"\(h)\">"]
        var depth = 1
        if clip {
            lines.append("  <defs><clipPath id=\"clip\"><rect width=\"\(w)\" height=\"\(h)\"/></clipPath></defs>")
            lines.append("  <g clip-path=\"url(#clip)\">")
            depth = 2
        }
        let origin = DesignPoint(x: box.x, y: box.y)
        for node in nodes { write(node, origin: origin, depth: depth, into: &lines) }
        if clip { lines.append("  </g>") }
        lines.append("</svg>")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Appends `node` and its visible subtree, `origin` subtracted from every coordinate.
    private static func write(_ node: DesignNode, origin: DesignPoint, depth: Int, into lines: inout [String]) {
        guard !node.isHidden else { return }
        let pad = String(repeating: "  ", count: depth)
        let f = node.frame
        let (x, y) = (f.x - origin.x, f.y - origin.y)
        let box = "x=\"\(number(x))\" y=\"\(number(y))\" width=\"\(number(f.width))\" height=\"\(number(f.height))\""
        if node.kind != .group, let defs = gradient(node, x: x, y: y) { lines.append(pad + defs) }
        switch node.kind {
        case .rectangle, .instance, .shape:  // a shape writes its box until DS-6 writes its path
            lines.append(pad + "<rect \(box)\(corner(node))\(fill(node))\(paint(node))\(alpha(node))/>")
        case .ellipse:
            let (rx, ry) = (f.width / 2, f.height / 2)
            let at = "cx=\"\(number(x + rx))\" cy=\"\(number(y + ry))\" rx=\"\(number(rx))\" ry=\"\(number(ry))\""
            lines.append(pad + "<ellipse \(at)\(fill(node))\(paint(node))\(alpha(node))/>")
        case .text:
            lines.append(pad + text(node, x: x, y: y))
        case .group:
            lines.append(pad + "<g\(alpha(node))>")
            for child in node.children { write(child, origin: origin, depth: depth + 1, into: &lines) }
            lines.append(pad + "</g>")
        case .frame:
            let id = XMLText.escaped("clip-" + node.id)
            lines.append(pad + "<clipPath id=\"\(id)\"><rect \(box)\(corner(node))/></clipPath>")
            lines.append(pad + "<g clip-path=\"url(#\(id))\"\(alpha(node))>")
            lines.append(pad + "  <rect \(box)\(corner(node))\(fill(node))\(paint(node))/>")
            for child in node.children { write(child, origin: origin, depth: depth + 1, into: &lines) }
            lines.append(pad + "</g>")
        }
    }

    /// A text layer: its anchor follows the alignment, its baseline sits one font size below the top.
    private static func text(_ node: DesignNode, x: Double, y: Double) -> String {
        let style = node.textStyle
        let (anchorX, anchor): (Double, String?) = switch style.alignment {
        case .leading: (x, nil)
        case .center: (x + node.frame.width / 2, "middle")
        case .trailing: (x + node.frame.width, "end")
        }
        let family = style.family == "System" ? "system-ui" : style.family
        var out = "<text x=\"\(number(anchorX))\" y=\"\(number(y + style.size))\" font-size=\"\(number(style.size))\""
        out += " font-family=\"\(XMLText.escaped(family))\""
        if style.weight != 400 { out += " font-weight=\"\(style.weight)\"" }
        if let anchor { out += " text-anchor=\"\(anchor)\"" }
        out += "\(fill(node))\(alpha(node))>\(XMLText.escaped(node.text))</text>"
        return out
    }

    /// The `<defs>` holding `node`'s gradient as SuiteKernel's GradientSVG writes it, its points in the layer's
    /// frame at `x`, `y` (box-relative, userSpaceOnUse); nil for a solid fill.
    private static func gradient(_ node: DesignNode, x: Double, y: Double) -> String? {
        let frame = Rect(minX: x, minY: y, maxX: x + node.frame.width, maxY: y + node.frame.height)
        let definition = GradientSVG.definition(node.fill(in: frame), id: gradientID(node))
        return definition.isEmpty ? nil : "<defs>" + definition + "</defs>"
    }

    /// ` fill="url(#g-…)"` for a layer with a linear or radial gradient, ` fill="#rrggbb"` otherwise.
    private static func fill(_ node: DesignNode) -> String {
        guard let gradient = node.gradient, GradientRules.type(of: gradient) != .solid else { return " fill=\"\(hex(node.fill))\"" }
        return " fill=\"url(#\(gradientID(node)))\""
    }

    /// The id of a layer's gradient definition: `g-` and its escaped node id.
    private static func gradientID(_ node: DesignNode) -> String { XMLText.escaped("g-" + node.id) }

    /// ` rx="r"` for a rounded rectangle or frame (the radius the canvas draws); empty when square.
    private static func corner(_ node: DesignNode) -> String {
        let radius = node.drawnCornerRadius
        return radius > 0 ? " rx=\"\(number(radius))\"" : ""
    }

    /// ` stroke="#rrggbb"`, plus ` stroke-width` when not 1; empty with no stroke or a width that draws nothing.
    private static func paint(_ node: DesignNode) -> String {
        guard let stroke = node.stroke, stroke.width.isFinite, stroke.width > 0 else { return "" }
        let width = stroke.width == 1 ? "" : " stroke-width=\"\(number(stroke.width))\""
        return " stroke=\"\(hex(stroke.color))\"" + width
    }

    /// ` opacity="o"` (kept within 0...1) when the layer is not fully opaque; empty otherwise.
    private static func alpha(_ node: DesignNode) -> String {
        let value = node.opacity.isFinite ? Swift.min(Swift.max(node.opacity, 0), 1) : 1
        return value < 1 ? " opacity=\"\(number(value))\"" : ""
    }

    /// `#rrggbb`, lowercase.
    static func hex(_ color: DesignColor) -> String {
        func pair(_ byte: UInt8) -> String { (byte < 16 ? "0" : "") + String(byte, radix: 16) }
        return "#" + pair(color.red) + pair(color.green) + pair(color.blue)
    }

    /// A coordinate: whole values without a fraction ("100", not "100.0"), others in Swift's
    /// shortest form; a value that is not finite writes 0.
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if value == value.rounded(), value.magnitude < 1e15 { return String(Int(value)) }
        return "\(value)"
    }
}
