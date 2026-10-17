// DesignWindowOptions.swift: what Design's window reads from its launch
// arguments, parsed once: `-DesignServices fake` (else the live services),
// `-DesignFixture <name>` (a DesignFixtures name opened as an unsaved file) and
// `-DesignWindowSize WxH` (both above zero, else nil; the app floors it at the
// suite's minimum window size). The size parse matches SuiteUI's
// SuiteWindowSize.parse, which is macOS-only, so the Model holds its own copy.
// Also here: `openFixture(_:)`, the status line's selection count text, and
// DesignControlID, every tier-1 `design.*` accessibility identifier declared up
// front so the views and journeys share one list: each is `design.<area>.<name>`,
// lowercase and dot-separated, and appears once (DesignControlIDTests). The
// window registers its own controls under these ids with `.suiteControl`: the
// toolbar items, each palette tool, the canvas and the status line. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What the window reads from its launch arguments; parsed once.
public struct DesignWindowOptions: Sendable, Equatable {
    /// `-DesignServices fake`, else `.live`.
    public var services: DesignServices
    /// `-DesignFixture <name>`; nil when absent.
    public var fixture: String?
    /// `-DesignWindowSize 880x560`; nil when absent or malformed. The app floors it at SuiteSize.windowMinimum.
    public var windowWidth: Double?
    public var windowHeight: Double?

    public init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        services = value(after: "-DesignServices") == "fake" ? .fake : .live
        fixture = value(after: "-DesignFixture")
        let size = value(after: "-DesignWindowSize").flatMap(Self.size)
        windowWidth = size?.width
        windowHeight = size?.height
    }

    /// "880x560" as two finite numbers above zero; nil otherwise.
    static func size(_ text: String) -> (width: Double, height: Double)? {
        let parts = text.split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]),
              width.isFinite, height.isFinite, width > 0, height > 0
        else { return nil }
        return (width, height)
    }
}

extension DesignWorkspace {
    /// Opens the fixture called `name` (DesignFixtures.names) as an unsaved file: no URL and
    /// nothing to undo, like Open; the services stay. False, changing nothing, for an unknown name.
    public mutating func openFixture(_ name: String) -> Bool {
        guard let fixture = DesignFixtures.named(name) else { return false }
        endDrag()
        commitTextEdit()
        load(fixture.pages)
        documentURL = nil
        return true
    }

    /// "2 Layers" with several selected, "1 Layer" with one, nil with none.
    public var selectionCountText: String? {
        switch selectedNodeIDs.count {
        case 0: nil
        case 1: "1 Layer"
        case let count: "\(count) Layers"
        }
    }
}

/// Every tier-1 `design.*` control id, declared up front so the wave-1 views use it without
/// editing this file; a missing id goes through the design-window feature's lane.
public enum DesignControlID {
    /// The canvas itself; it keeps SuiteUI's `suite.canvas` identifier and is listed under this id.
    public static let canvas = "design.canvas.page"
    public static let canvasSelection = "design.canvas.selection"
    public static let canvasHover = "design.canvas.hover"
    public static let canvasBadge = "design.canvas.badge"
    public static let canvasGuides = "design.canvas.guides"
    public static let canvasMarquee = "design.canvas.marquee"
    public static let statusTool = "design.status.tool"
    public static let statusSave = "design.status.save"
    public static let statusSelection = "design.status.selection"
    public static let statusNote = "design.status.note"
    /// The Layers panel's container identifier, which journeys query; a region, not a control,
    /// so it is left out of `all`.
    public static let layers = "design.layers"
    public static let pageAdd = "design.page.add"
    public static let pageDelete = "design.page.delete"
    public static let inspectorHeader = "design.inspector.header"
    public static let inspectorFill = "design.inspector.fill"
    public static let inspectorCornerRadius = "design.inspector.corner-radius"
    public static let inspectorOpacity = "design.inspector.opacity"
    public static let inspectorStrokeColor = "design.inspector.stroke-color"
    public static let inspectorStrokeWidth = "design.inspector.stroke-width"
    public static let inspectorTextFamily = "design.inspector.text-family"
    public static let inspectorTextSize = "design.inspector.text-size"
    public static let inspectorTextWeight = "design.inspector.text-weight"
    public static let inspectorTextAlignment = "design.inspector.text-alignment"
    public static let inspectorPageWidth = "design.inspector.page-width"
    public static let inspectorPageHeight = "design.inspector.page-height"

    /// A palette tool: "design.tool.rectangle".
    public static func tool(_ tool: DesignTool) -> String { "design.tool.\(tool.rawValue)" }
    /// An inspector frame field: "design.inspector.width".
    public static func frameField(_ field: DesignFrameField) -> String { "design.inspector.\(field.rawValue)" }
    /// An Align button: "design.align.left".
    public static func align(_ edge: DesignAlignEdge) -> String { "design.align.\(edge.rawValue)" }
    /// A Distribute button: "design.distribute.horizontal".
    public static func distribute(_ axis: DesignDistributeAxis) -> String { "design.distribute.\(axis.rawValue)" }

    /// Every fixed id: the named ones, the toolbar's, and one per tool, frame field, edge and axis.
    public static let all: [String] = [
        canvas, canvasSelection, canvasHover, canvasBadge, canvasGuides, canvasMarquee,
        statusTool, statusSave, statusSelection, statusNote, pageAdd, pageDelete,
        inspectorHeader, inspectorFill, inspectorCornerRadius, inspectorOpacity,
        inspectorStrokeColor, inspectorStrokeWidth, inspectorTextFamily, inspectorTextSize,
        inspectorTextWeight, inspectorTextAlignment, inspectorPageWidth, inspectorPageHeight,
    ] + DesignToolbarItem.allCases.map(\.identifier) + DesignTool.allCases.map(tool)
        + DesignFrameField.allCases.map(frameField) + DesignAlignEdge.allCases.map(align)
        + DesignDistributeAxis.allCases.map(distribute)
}
