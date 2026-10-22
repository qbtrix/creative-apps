// PhotoCanvasSizeDraft.swift: the Canvas Size sheet's choices (transform
// PT-3): a width and height in pixels, either absolute or relative (added to
// the image's size), and the BoxAnchor the image keeps its place at. Each
// change returns a new draft, so the sheet sends values out; fields clamp so
// every side stays 1...PhotoWorkspace.maxSide, switching between relative and
// absolute keeps the size, and a smaller side brings the crop note. OK goes to
// PhotoWorkspace.resizeCanvas(width:height:anchor:). Linux-safe.
import SuiteKernel

public struct CanvasSizeDraft: Sendable, Hashable {
    /// The image's size when the sheet opened.
    public let old: CanvasSize
    /// True when the fields hold amounts added to the image's size.
    public private(set) var relative: Bool
    /// The width field's value: the new width, or the amount added when relative.
    public private(set) var width: Int
    /// The height field's value: the new height, or the amount added when relative.
    public private(set) var height: Int
    /// Where the image sits in the new canvas.
    public private(set) var anchor: BoxAnchor

    /// The image's own size, centred; relative fields start at 0.
    public init(old: CanvasSize, relative: Bool = false, anchor: BoxAnchor = .center) {
        self.old = old
        self.relative = relative
        self.anchor = anchor
        width = relative ? 0 : old.width
        height = relative ? 0 : old.height
    }

    /// The canvas size OK makes.
    public var newSize: CanvasSize {
        relative ? CanvasSize(width: old.width + width, height: old.height + height) : CanvasSize(width: width, height: height)
    }

    /// The values the width field takes, so the new width stays 1...maxSide.
    public var widthRange: ClosedRange<Int> { Self.range(old: old.width, relative: relative) }
    /// The values the height field takes, so the new height stays 1...maxSide.
    public var heightRange: ClosedRange<Int> { Self.range(old: old.height, relative: relative) }

    /// True when either side is smaller than the image's, so pixels are cut.
    public var crops: Bool {
        let size = newSize
        return size.width < old.width || size.height < old.height
    }

    /// The note under the fields when the canvas shrinks.
    public var cropNote: String? { crops ? "The canvas will be cropped." : nil }

    /// Why OK is off; nil when it can run.
    public var help: String? { newSize == old ? "Choose a size different from the image's." : nil }

    /// The fields switched to relative (or absolute), keeping the new size.
    public func with(relative on: Bool) -> Self {
        guard on != relative else { return self }
        let size = newSize
        var next = self
        next.relative = on
        next.width = on ? size.width - old.width : size.width
        next.height = on ? size.height - old.height : size.height
        return next
    }

    /// The width field set to `value`, clamped to `widthRange`.
    public func with(width value: Int) -> Self {
        var next = self
        next.width = min(max(value, widthRange.lowerBound), widthRange.upperBound)
        return next
    }

    /// The height field set to `value`, clamped to `heightRange`.
    public func with(height value: Int) -> Self {
        var next = self
        next.height = min(max(value, heightRange.lowerBound), heightRange.upperBound)
        return next
    }

    /// The anchor grid's choice.
    public func with(anchor value: BoxAnchor) -> Self {
        var next = self
        next.anchor = value
        return next
    }

    /// The anchor grid's label for `anchor`.
    public static func anchorTitle(_ anchor: BoxAnchor) -> String {
        switch anchor {
        case .topLeft: "Top Left"
        case .top: "Top"
        case .topRight: "Top Right"
        case .left: "Left"
        case .center: "Center"
        case .right: "Right"
        case .bottomLeft: "Bottom Left"
        case .bottom: "Bottom"
        case .bottomRight: "Bottom Right"
        }
    }

    private static func range(old: Int, relative: Bool) -> ClosedRange<Int> {
        relative ? (1 - old)...(PhotoWorkspace.maxSide - old) : 1...PhotoWorkspace.maxSide
    }
}
