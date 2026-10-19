// LibraryCropOverlay.swift: the crop frame over the loupe's photo while a
// draft is open (crop CR-6), in CanvasViewport's overlay at the artboard's
// zoom: SuiteUI's CropShade (the outside dimmed, the frame and its thirds),
// a SelectionOutline on the frame, and eight square handles at its corners
// and edge midpoints. Plain handles until SuiteUI's CropHandles (#3116). It
// takes no hits: the loupe's canvas drag picks the handle under the press
// with `handle(at:frame:radius:)` and reports the drag through
// `LibraryMenu.Crop.drag`, so the canvas keeps the keys (Escape cancels, the
// arrows nudge). Its elements: the frame `library.crop.frame`, a ProbeElement
// whose label reads `cropFrameValue` ("4000 × 4000 at 1000, 0"), and each handle
// `library.crop.handle.<name>` ("library.crop.handle.topLeft"), placed where
// they are drawn. Values in; it never writes LibraryCatalog.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryCropOverlay: View {
    let crop: LibraryMenu.Crop
    /// Points per photo pixel: the loupe's zoom.
    let zoom: Double

    var body: some View {
        if let frame = crop.frame, let canvas = crop.canvas {
            let rect = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
            let box = rect.applying(CGAffineTransform(scaleX: zoom, y: zoom))
            let label = crop.frameValue ?? ""
            ZStack(alignment: .topLeading) {
                CropShade(rect: rect, documentSize: CGSize(width: canvas.width, height: canvas.height), zoom: zoom)
                SelectionOutline(rect: rect, zoom: zoom)
                ProbeElement("library.crop.frame", label: label, rect: rect, zoom: zoom)
                ForEach(Self.handles, id: \.self) { handle in
                    let point = Self.point(of: handle, in: box)
                    Rectangle()
                        .fill(SuiteColor.overlayPaper)
                        .overlay(Rectangle().strokeBorder(SuiteColor.overlayInk, lineWidth: 1))
                        .frame(width: SuiteSize.selectionHandle, height: SuiteSize.selectionHandle)
                        .accessibilityElement()
                        .accessibilityLabel(Text(verbatim: "Crop handle"))
                        .accessibilityIdentifier(Self.handleID(handle))
                        .position(point)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    /// The eight handles drawn on the frame; `.inside` is the frame itself.
    nonisolated static let handles = CropHandle.allCases.filter { $0 != .inside }

    /// `library.crop.handle.<name>`, as "library.crop.handle.topLeft".
    nonisolated static func handleID(_ handle: CropHandle) -> String { "library.crop.handle.\(handle)" }

    /// Where `handle` sits on `box`: a corner or an edge's midpoint; the centre for `.inside`.
    nonisolated static func point(of handle: CropHandle, in box: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: box.minX, y: box.minY)
        case .top: CGPoint(x: box.midX, y: box.minY)
        case .topRight: CGPoint(x: box.maxX, y: box.minY)
        case .right: CGPoint(x: box.maxX, y: box.midY)
        case .bottomRight: CGPoint(x: box.maxX, y: box.maxY)
        case .bottom: CGPoint(x: box.midX, y: box.maxY)
        case .bottomLeft: CGPoint(x: box.minX, y: box.maxY)
        case .left: CGPoint(x: box.minX, y: box.midY)
        case .inside: CGPoint(x: box.midX, y: box.midY)
        }
    }

    /// The handle a press at `location` grabs: the nearest within `radius`
    /// (all in photo pixels) of its point on `frame`, else `.inside`.
    nonisolated static func handle(at location: CGPoint, frame: CGRect, radius: Double) -> CropHandle {
        var best = CropHandle.inside
        var nearest = CGFloat(radius)
        for handle in handles {
            let point = point(of: handle, in: frame)
            let distance = max(abs(point.x - location.x), abs(point.y - location.y))
            if distance <= nearest {
                best = handle
                nearest = distance
            }
        }
        return best
    }
}
