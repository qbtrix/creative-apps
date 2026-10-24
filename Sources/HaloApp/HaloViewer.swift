// HaloViewer.swift: Halo's main content: HaloViewerCanvas with the Shape
// button (HaloShapeTool, shape-tools HS-2) at its top trailing corner, the Model's
// `viewerNotice` captioned under it while layers can't be drawn, a status bar
// with HaloTransport and the History button beside it, HaloTimelineView and a refusal's caption, or the empty
// state. The status bar's tooltips (HaloStatusText) say what the timecode's
// four parts count and that the pills are zoom and pixel size. A narrow
// column takes HaloStatusRow's shapes in turn: it drops the layer count,
// then moves the transport and History out of their pills to the row's
// leading edge (L5: transport left, pills right), then drops the zoom pill,
// then the timecode; the transport and History never go (#4272, #4449),
// and the content adds no width to SuiteWindow's minimum. Space, ←, →,
// Home, End, I and O become HaloCommands sent to `perform`, and ⌫ (the
// delete command) sends the Model's `deleteCommand`: the picked keys while any
// are picked, else the selected layer, as in the layer list. Files dropped on
// the canvas are placed at the drop point through the window's `haloPlace`
// (PH-3). Any other file dropped on the viewer, or the empty state, follows
// the suite's drop rule (file-flow HF-2, `suiteFileDrop`): a .halo opens
// through HaloShell's host, a file another app reads goes to that app.
// Views only read HaloProject; state lives in HaloModel.
import HaloModel
import SuiteKernel
import SuiteShell
import SuiteUI
import SwiftUI

struct HaloViewer: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    /// Where the Shape popover's options go (HaloShapeTool).
    var onShapeIntent: @MainActor (ShapeIntent) -> Void = { _ in }
    /// The viewer's size, for the zoom CanvasSurface fits the artboard at.
    @State private var viewport = CGSize.zero
    /// The window's place action (HaloPlace.swift) and the Fill preference a drop reads.
    @Environment(\.haloPlace) private var place
    @AppStorage(HaloPlace.fillKey) private var fill = false

    private var placeHelp: String? { HaloPlace.help(model, place) }

    var body: some View {
        viewer.suiteFileDrop(.halo, bridge: HaloShell.bridge, host: HaloShell.host, hasDocument: model.hasDocument,
                             places: model.placesExtensions, documentName: model.file.name)
    }

    @ViewBuilder private var viewer: some View {
        if let comp = model.selectedComposition {
            let artboard = CGSize(width: comp.width, height: comp.height)
            VStack(spacing: 0) {
                HaloViewerCanvas(model: model, perform: perform)
                    .overlay { HaloViewerHandles(model: model) }
                    // PH-3: files dropped here are placed at the drop point; no formats while placing is off.
                    .placeDropTarget(formats: placeHelp == nil ? model.placeFormats : []) { files, point in
                        guard let place, placeHelp == nil else { return false }
                        let at = HaloPlace.compositionPoint(point, viewer: viewport, composition: artboard)
                        for file in files { place(.place(name: file.name, data: file.data, at: at), fill) }
                        return !files.isEmpty
                    }
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { viewport = $0 }
                    // Top trailing, clear of the drag journey's top-leading surround.
                    .overlay(alignment: .topTrailing) {
                        HaloShapeTool(model: model, onIntent: onShapeIntent).padding(SuiteSpacing.s)
                    }
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
                // The widest row that fits (HaloStatusRow.fallbacks, in its
                // order), so the status bar never holds the content column
                // wider than SuiteWindow's minimum. At 440 pt the bare
                // transport, History and three pills need about 456, so the
                // zoom pill goes there (#4449).
                ViewThatFits(in: .horizontal) {
                    ForEach(HaloStatusRow.fallbacks, id: \.self) { statusRow(comp, artboard: artboard, $0) }
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

    /// One shape of the status row: the bar alone, or the bare transport
    /// and History at the leading edge, their 24 pt squares edge to edge
    /// with no pill around them, and the bar's pills right.
    @ViewBuilder
    private func statusRow(_ comp: HaloComposition, artboard: CGSize, _ row: HaloStatusRow) -> some View {
        if row.transportInBar {
            statusBar(comp, artboard: artboard, row)
        } else {
            HStack(spacing: 0) {
                HaloTransport(model: model, perform: perform)
                if row.history { HaloHistoryControl() }
                statusBar(comp, artboard: artboard, row)
            }
            .background(SuiteColor.panel)
        }
    }

    /// The status bar with the pills `row` asks for. ViewerStatusBar's
    /// zoom and size pills take no help of their own; the bar's tooltip names
    /// them, and each trailing pill keeps its own.
    private func statusBar(_ comp: HaloComposition, artboard: CGSize, _ row: HaloStatusRow) -> some View {
        let zoom: Double? = row.zoom ? ViewerZoom.fitScale(artboard: artboard, in: viewport) : nil
        return ViewerStatusBar(zoom: zoom, size: comp.sizeText) {
            if row.timecode {
                // The current time in primary ink, in the pill type so the
                // bar fits the content column; the length is in the tooltip.
                // The playing frame's time, re-run alone per frame (HaloPlayheadShown).
                // Sized to the composition's widest line, drawn hidden under
                // it, with fixed-width digits: a playing timecode never
                // changes the row's width, so ViewThatFits keeps one shape and
                // never swaps the transport out from under a click (#4586).
                Text(comp.statusTimecodeWidest).hidden().accessibilityHidden(true)
                    .overlay(alignment: .leading) {
                        HaloPlayheadShown(model: model) { Text(($0.selectedComposition ?? comp).statusTimecode) }
                    }
                    .monospacedDigit()
                    .foregroundStyle(SuiteColor.textPrimary)
                    .help(comp.statusTimecodeHelp)
            }
            if row.layers { Text(comp.layerSummary).help("Layers in this composition.") }
            if row.transportInBar {
                HaloTransport(model: model, perform: perform)
                if row.history { HaloHistoryControl() }
            }
        }
        .help(row.pillsHelp)
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

