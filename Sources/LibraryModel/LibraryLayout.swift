// LibraryLayout.swift: the window's layout math (status-and-layout SL-1):
// the content width between sidebar and inspector, the grid's column count
// and the loupe's fit scale. LibraryModel can't import SuiteUI, so the tokens
// are stored values whose defaults LibraryLayoutSnapshots checks against
// SuiteSize and SuiteSpacing. Foundation free, Linux-safe.

public struct LibraryLayout: Hashable, Sendable {
    /// SuiteSize.sidebarWidth.ideal and SuiteSize.inspectorWidth.ideal.
    public var sidebar = 200.0, inspector = 240.0
    /// SuiteSpacing.m: the grid's outer padding and the gap between cells.
    public var gridPadding = 12.0, gridSpacing = 12.0
    /// SuiteSpacing.xs: the inset around each thumbnail inside its cell.
    public var cellInset = 4.0
    /// SuiteSize.canvasInset: the loupe's margin on each side.
    public var canvasInset = 64.0

    public init() {}

    /// The width between the sidebar and the inspector, never below 0.
    public func contentWidth(window: Double) -> Double {
        max(0, window - sidebar - inspector)
    }

    /// How many `cell`-wide thumbnails fit across `contentWidth`, equal to
    /// GridSelection.columns over the padded width: 1 for a degenerate width
    /// or cell, never above 10,000.
    public func gridColumns(contentWidth: Double, cell: Double) -> Int {
        let pitch = cell + 2 * cellInset + gridSpacing
        guard pitch > 0, pitch.isFinite, contentWidth.isFinite else { return 1 }
        let fit = ((contentWidth - 2 * gridPadding + gridSpacing) / pitch).rounded(.down)
        // Clamped before Int(_:), which traps on a value past Int's range.
        return Int(min(max(fit, 1), 10_000))
    }

    /// The scale that fits `photo` in `viewport` leaving canvasInset on the
    /// tighter axis; 1 when the photo is empty, never below 0.
    public func loupeFit(viewport: (width: Double, height: Double), photo: PixelSize) -> Double {
        guard photo.width > 0, photo.height > 0 else { return 1 }
        let margin = 2 * canvasInset
        let scale = min((viewport.width - margin) / Double(photo.width),
                        (viewport.height - margin) / Double(photo.height))
        return scale.isNaN ? 1 : max(0, scale)
    }
}
