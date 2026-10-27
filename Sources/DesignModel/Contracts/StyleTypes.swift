// Contracts/StyleTypes.swift: the style values DesignNode gains in task D0-1
// (corner radius, opacity, stroke, text style) and the tier-2 values (paths,
// components, variables) that D2-1 adds to the file. Value types, Codable, so
// they go into a file as they are. Linux-safe.
import SuiteKernel

/// A stroke drawn centered on the shape's outline: the kernel's, with its join, cap and dash (stroke-style DK-5).
/// Points; 0 draws nothing. The inspector clamps the width to 0...1000.
public typealias DesignStroke = VectorStroke

extension VectorStroke {
    /// A solid stroke of Design's opaque `color`, `width` points wide, with the default join and cap.
    public init(color: DesignColor, width: Double) {
        self.init(color: color.kernelColor, width: width)
    }

    /// The 1 pt black stroke Add Stroke gives.
    public static let `default` = VectorStroke()
}

public enum DesignTextAlignment: String, CaseIterable, Sendable, Codable { case leading, center, trailing }

/// How a text layer's text is set. The app measures and draws it; the Model only stores it.
public struct DesignTextStyle: Sendable, Hashable, Codable {
    /// A family name the system font list offers; "System" is the system font.
    public var family: String
    /// Points, 1...1000.
    public var size: Double
    /// 100...900 in steps of 100, as CSS and OpenType name weights.
    public var weight: Int
    public var alignment: DesignTextAlignment
    /// nil or false: the box fits its text (a Text click); true: it keeps its width and the
    /// text wraps (a Text drag, canvas-basics CB-3). Left out of the file when nil, so a file
    /// written before it opens as auto width and keeps its bytes.
    public var fixedWidth: Bool?

    public init(
        family: String, size: Double, weight: Int, alignment: DesignTextAlignment, fixedWidth: Bool? = nil
    ) {
        (self.family, self.size, self.weight, self.alignment) = (family, size, weight, alignment)
        self.fixedWidth = fixedWidth
    }

    private enum CodingKeys: String, CodingKey { case family, size, weight, alignment, fixedWidth }

    /// Decodes a style; a file without `fixedWidth` is auto width (nil). The synthesized
    /// encoder leaves a nil `fixedWidth` out.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            family: container.decode(String.self, forKey: .family), size: container.decode(Double.self, forKey: .size),
            weight: container.decode(Int.self, forKey: .weight),
            alignment: container.decode(DesignTextAlignment.self, forKey: .alignment),
            fixedWidth: container.decodeIfPresent(Bool.self, forKey: .fixedWidth))
    }

    public static let `default` = DesignTextStyle(family: "System", size: 16, weight: 400, alignment: .leading)
}

/// The style properties the inspector edits, for help lookups.
public enum DesignStyleProperty: String, CaseIterable, Sendable { case frame, fill, cornerRadius, opacity, stroke, textStyle }

/// One of the inspector's X, Y, W and H fields; with several layers selected it sets each layer's own value.
public enum DesignFrameField: String, CaseIterable, Sendable { case x, y, width, height }

/// One pen anchor: where it sits and its two curve handles, absolute page points. No handle is a corner.
public struct DesignAnchor: Sendable, Hashable, Codable {
    public var point: DesignPoint
    public var handleIn: DesignPoint?
    public var handleOut: DesignPoint?

    public init(point: DesignPoint, handleIn: DesignPoint? = nil, handleOut: DesignPoint? = nil) {
        (self.point, self.handleIn, self.handleOut) = (point, handleIn, handleOut)
    }
}

/// A pen path: anchors joined by cubic segments (a straight one when both handles are absent).
public struct DesignPath: Sendable, Hashable, Codable {
    public var anchors: [DesignAnchor]
    public var isClosed: Bool

    public init(anchors: [DesignAnchor], isClosed: Bool) {
        (self.anchors, self.isClosed) = (anchors, isClosed)
    }
}

/// A component: a named master tree that instances draw. Its nodes are relative to its own top-left.
public struct DesignComponent: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public var name: String
    public var width: Double
    public var height: Double
    public var nodes: [DesignNode]

    public init(id: String, name: String, width: Double, height: Double, nodes: [DesignNode]) {
        (self.id, self.name, self.width, self.height, self.nodes) = (id, name, width, height, nodes)
    }
}

public enum DesignMode: String, CaseIterable, Sendable, Codable { case light, dark }

public enum DesignVariableValue: Sendable, Hashable, Codable {
    case color(DesignColor)
    case number(Double)
}

/// A named value with one value per mode.
public struct DesignVariable: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public var name: String
    public var light: DesignVariableValue
    public var dark: DesignVariableValue

    public init(id: String, name: String, light: DesignVariableValue, dark: DesignVariableValue) {
        (self.id, self.name, self.light, self.dark) = (id, name, light, dark)
    }

    public func value(in mode: DesignMode) -> DesignVariableValue { mode == .light ? light : dark }
}

/// What an export writes. Its file extension and rules are the kernel's (`fileExtension`, DesignExport+Kernel).
public enum DesignExportFormat: String, CaseIterable, Sendable { case png, jpeg, svg, pdf }

/// One file an export writes.
public struct DesignExportItem: Sendable, Equatable {
    public var nodeID: String
    /// "Card.png", "Card 2.png": unique in the folder.
    public var fileName: String
    /// The item's size in points, and the exact pixels the file is (equal for SVG and PDF).
    public var width: Double
    public var height: Double
    public var pixelWidth: Int
    public var pixelHeight: Int
    /// The color a format without alpha (JPEG) flattens onto; nil keeps transparency.
    public var background: DesignColor?

    public init(nodeID: String, fileName: String, width: Double, height: Double, pixelWidth: Int, pixelHeight: Int,
                background: DesignColor? = nil) {
        (self.nodeID, self.fileName, self.width, self.height) = (nodeID, fileName, width, height)
        (self.pixelWidth, self.pixelHeight, self.background) = (pixelWidth, pixelHeight, background)
    }
}

public enum DesignDistributeAxis: String, CaseIterable, Sendable {
    case horizontal, vertical

    public var title: String { self == .horizontal ? "Distribute Horizontally" : "Distribute Vertically" }
}

public enum DesignArrangeStep: String, CaseIterable, Sendable {
    case bringToFront, bringForward, sendBackward, sendToBack

    public var title: String {
        switch self {
        case .bringToFront: "Bring to Front"
        case .bringForward: "Bring Forward"
        case .sendBackward: "Send Backward"
        case .sendToBack: "Send to Back"
        }
    }
}
