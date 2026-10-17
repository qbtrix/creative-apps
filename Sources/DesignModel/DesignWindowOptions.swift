// DesignWindowOptions.swift: what Design's window reads from its launch arguments
// (`-DesignServices fake`, `-DesignFixture <name>`, `-DesignWindowSize WxH`), parsed
// once. Also the window-facing workspace reads the status line and the toolbar use:
// the open-a-fixture action, the layer count, and Zoom to Selection's rect and reason.
// Every control id the wave-1 views use is declared in DesignControlID. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What the window reads from its launch arguments; parsed once.
public struct DesignWindowOptions: Sendable, Equatable {
    /// `-DesignServices fake` selects the fixture fakes; anything else, or no flag, is `.live`.
    public var services: DesignServices = .live
    /// `-DesignFixture <name>`: the named fixture to open, if the argument has a value.
    public var fixture: String?
    /// `-DesignWindowSize 880x560`; nil when absent or malformed. The app floors it at SuiteSize.windowMinimum.
    public var windowWidth: Double?
    public var windowHeight: Double?

    public init(arguments: [String]) {
        // The value after `flag`, or nil when the flag is last or absent.
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        if value(after: "-DesignServices") == "fake" { services = .fake }
        fixture = value(after: "-DesignFixture")
        if let size = value(after: "-DesignWindowSize") {
            let parts = size.split(separator: "x", omittingEmptySubsequences: false).map { Double($0) }
            if parts.count == 2, let width = parts[0], let height = parts[1],
               width.isFinite, height.isFinite, width > 0, height > 0 {
                (windowWidth, windowHeight) = (width, height)
            }
        }
    }
}

/// Every tier-1 `design.*` control id, declared up front so the wave-1 views use it
/// without editing this file; a missing id goes through this feature's lane.
public enum DesignControlID {
    public static let barNew = "design.bar.new"
    public static let barOpen = "design.bar.open"
    public static let barSave = "design.bar.save"
    public static let barUndo = "design.bar.undo"
    public static let barRedo = "design.bar.redo"
    public static let barZoomOut = "design.bar.zoom-out"
    public static let barFit = "design.bar.fit"
    public static let barZoomIn = "design.bar.zoom-in"
    public static let pageAdd = "design.page.add"
    public static let pageDelete = "design.page.delete"
    public static let layers = "design.layers"
    public static let currentPage = "design.current-page"
    public static let properties = "design.properties"
    public static let inspectorPageWidth = "design.inspector.page-width"
    public static let inspectorPageHeight = "design.inspector.page-height"
    public static let statusTool = "design.status.tool"
    public static let statusSave = "design.status.save"
    public static let statusSelection = "design.status.selection"
    public static let canvasSelection = "design.canvas.selection"
    public static let canvasHover = "design.canvas.hover"
    public static let canvasBadge = "design.canvas.badge"
    public static let canvasGuides = "design.canvas.guides"

    public static let all: [String] = [
        barNew, barOpen, barSave, barUndo, barRedo, barZoomOut, barFit, barZoomIn, pageAdd, pageDelete,
        layers, currentPage, properties, inspectorPageWidth, inspectorPageHeight, statusTool, statusSave,
        statusSelection, canvasSelection, canvasHover, canvasBadge, canvasGuides,
    ]
}

extension DesignWorkspace {
    /// Opens a named fixture as an unsaved file, like Open: no location, empty history. The
    /// services stay as they are. False, with the workspace unchanged, for an unknown name.
    public mutating func openFixture(_ name: String) -> Bool {
        guard var fixture = DesignFixtures.named(name) else { return false }
        fixture.services = services
        self = fixture
        return true
    }

    /// "1 Layer" with one layer selected, "2 Layers" with several, nil with none.
    public var selectionCountText: String? {
        let count = selectedNodeIDs.count
        if count == 0 { return nil }
        return count == 1 ? "1 Layer" : "\(count) Layers"
    }

    /// The rect Zoom to Selection fits: the selection's box, or nil with nothing to show.
    public var zoomToSelectionRect: DesignRect? { selectionBounds }

    /// Why Zoom to Selection can't run now, as its tooltip; nil when it can.
    public var zoomToSelectionHelp: String? {
        selectedNodeIDs.isEmpty ? "Select a layer first." : nil
    }
}
