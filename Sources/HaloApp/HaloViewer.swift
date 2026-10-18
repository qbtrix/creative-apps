// HaloViewer.swift: Halo's main content: HaloViewerCanvas, the Model's
// `viewerNotice` captioned under it while layers can't be drawn, a status bar
// with HaloTransport, HaloTimelineView and a refusal's caption, or the empty
// state. The status bar's tooltips (HaloStatusText) say what the timecode's
// four parts count and that the pills are zoom and pixel size. A narrow
// column drops the layer count, then the transport, then the timecode, so the
// content adds no width to SuiteWindow's minimum. Space, ←, →,
// Home, End, I and O become HaloCommands sent to `perform`, and ⌫ (the
// delete command) sends the Model's `deleteCommand`: the picked keys while any
// are picked, else the selected layer, as in the layer list. Views only read HaloProject; state lives in HaloModel.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloViewer: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    /// The viewer's size, for the zoom CanvasSurface fits the artboard at.
    @State private var viewport = CGSize.zero

    var body: some View {
        if let comp = model.selectedComposition {
            let artboard = CGSize(width: comp.width, height: comp.height)
            VStack(spacing: 0) {
                HaloViewerCanvas(model: model, perform: perform)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { viewport = $0 }
                // Under the artboard, not over it: the layout journey reads
                // the artboard's frame from the viewer's pixels.
                if let notice = model.viewerNotice {
                    Label(notice, systemImage: "info.circle")
                        .font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SuiteSpacing.xs)
                        .background(SuiteColor.panel)
                        .accessibilityIdentifier("halo.viewer.notice")
                }
                // The widest bar that fits, so the status bar never holds the
                // content column wider than SuiteWindow's minimum: the layer
                // count goes first, then the transport, then the timecode.
                ViewThatFits(in: .horizontal) {
                    statusBar(comp, artboard: artboard, timecode: true, layers: true, transport: true)
                    statusBar(comp, artboard: artboard, timecode: true, layers: false, transport: true)
                    statusBar(comp, artboard: artboard, timecode: true, layers: false, transport: false)
                    statusBar(comp, artboard: artboard, timecode: false, layers: false, transport: false)
                }
                Divider()
                HaloTimelineView(model: model, perform: perform)
                if let refusal = model.refusal, !refusal.control.hasPrefix("halo.inspector") {
                    InspectorNote(refusal.message, kind: .error, identifier: "halo.refusal")
                }
            }
            .onKeyPress(keys: [.space, .leftArrow, .rightArrow, .home, .end]) { press in
                guard let command = Self.command(for: press.key) else { return .ignored }
                perform(command)
                return .handled
            }
            // ⌫ arrives as the delete command, as in the layer list; a key
            // press for .delete (U+0008) deleted nothing from the focused
            // timeline in run 38823293728.
            .onDeleteCommand { perform(model.deleteCommand) }
            .onKeyPress(characters: CharacterSet(charactersIn: "iIoO")) { press in
                perform(press.characters.lowercased() == "i" ? .setInPoint : .setOutPoint)
                return .handled
            }
        } else {
            EmptyStateView(
                "No Composition", systemImage: "sparkles.rectangle.stack",
                message: "Create a composition to layer and animate footage, shapes and text.",
                action: ToolbarAction("New Composition…", systemImage: "plus", identifier: "halo.viewer.newComposition") {
                    perform(.newComposition)
                })
        }
    }

    /// The status bar with the trailing pills asked for. ViewerStatusBar's
    /// zoom and size pills take no help of their own; the bar's tooltip names
    /// them, and each trailing pill keeps its own.
    private func statusBar(
        _ comp: HaloComposition, artboard: CGSize, timecode: Bool, layers: Bool, transport: Bool
    ) -> some View {
        ViewerStatusBar(zoom: ViewerZoom.fitScale(artboard: artboard, in: viewport), size: comp.sizeText) {
            if timecode {
                // The current time in primary ink, in the pill type so the
                // bar fits the content column; the length is in the tooltip.
                Text(comp.statusTimecode)
                    .foregroundStyle(SuiteColor.textPrimary)
                    .help(comp.statusTimecodeHelp)
            }
            if layers { Text(comp.layerSummary).help("Layers in this composition.") }
            if transport { HaloTransport(model: model, perform: perform) }
        }
        .help(HaloComposition.viewerPillsHelp)
    }

    /// The command a viewer key sends; nil for any other key.
    static func command(for key: KeyEquivalent) -> HaloCommand? {
        switch key {
        case .space: .playPause
        case .leftArrow: .previousFrame
        case .rightArrow: .nextFrame
        case .home: .goToStart
        case .end: .goToEnd
        default: nil
        }
    }
}

