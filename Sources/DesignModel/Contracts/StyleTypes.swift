// Contracts/StyleTypes.swift: the style values DesignNode gains in task D0-1
// (corner radius, opacity, stroke, text style) and the tier-2 values (paths,
// components, variables) that D2-1 adds to the file. Value types, Codable, so
// they go into a file as they are. Linux-safe.

/// A stroke drawn centered on the shape's outline.
public struct DesignStroke: Sendable, Hashable, Codable {
    public var color: DesignColor
    /// Points; 0 draws nothing. The inspector clamps it to 0...1000.
    public var width: Double

    public init(color: DesignColor, width: Double) {
        (self.color, self.width) = (color, width)
    }

    public static let `default` = DesignStroke(color: .black, width: 1)
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

    public init(family: String, size: Double, weight: Int, alignment: DesignTextAlignment) {
        (self.family, self.size, self.weight, self.alignment) = (family, size, weight, alignment)
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

public enum DesignExportFormat: String, CaseIterable, Sendable { case png, svg, pdf }

/// One file an export writes.
public struct DesignExportItem: Sendable, Equatable {
    public var nodeID: String
    /// "Card.png", "Card 2.png": unique in the folder.
    public var fileName: String
    /// The item's size in points, and in pixels at the export scale (equal for SVG and PDF).
    public var width: Double
    public var height: Double
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(nodeID: String, fileName: String, width: Double, height: Double, pixelWidth: Int, pixelHeight: Int) {
        (self.nodeID, self.fileName, self.width, self.height) = (nodeID, fileName, width, height)
        (self.pixelWidth, self.pixelHeight) = (pixelWidth, pixelHeight)
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
