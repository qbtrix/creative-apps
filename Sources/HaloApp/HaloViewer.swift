// HaloViewer.swift: Halo's main content: HaloViewerCanvas, the Model's
// `viewerNotice` captioned under it while layers can't be drawn, a status bar
// with HaloTransport, HaloTimelineView and a refusal's caption, or the empty
// state. The status bar's tooltips (HaloStatusText) say what the timecode's
// four parts count and that the pills are zoom and pixel size. Space, ←, →,
// Home, End, I, O and ⌫ become HaloCommands sent to `perform`. Views only read HaloProject; state lives in HaloModel.
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
                ViewerStatusBar(zoom: ViewerZoom.fitScale(artboard: artboard, in: viewport), size: comp.sizeText) {
                    Text(comp.statusTimecode).help(comp.statusTimecodeHelp)
                    Text(comp.layerSummary).help("Layers in this composition.")
                    HaloTransport(model: model, perform: perform)
                }
                // ViewerStatusBar's zoom and size pills take no help of their
                // own; the bar's tooltip names them, and each trailing pill
                // keeps its own.
                .help(HaloComposition.viewerPillsHelp)
                Divider()
                HaloTimelineView(model: model, perform: perform)
                if let refusal = model.refusal, !refusal.control.hasPrefix("halo.inspector") {
                    HaloRefusalCaption(refusal: refusal)
                }
            }
            .onKeyPress(keys: [.space, .leftArrow, .rightArrow, .home, .end, .delete]) { press in
                guard let command = Self.command(for: press.key) else { return .ignored }
                perform(command)
                return .handled
            }
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

    /// The command a viewer key sends; nil for any other key.
    static func command(for key: KeyEquivalent) -> HaloCommand? {
        switch key {
        case .space: .playPause
        case .leftArrow: .previousFrame
        case .rightArrow: .nextFrame
        case .home: .goToStart
        case .end: .goToEnd
        case .delete: .deleteLayer
        default: nil
        }
    }
}

/// A refused edit's message under the control that refused it, in the error
/// state's color and symbol (docs/design.md, States).
struct HaloRefusalCaption: View {
    let refusal: HaloRefusal

    var body: some View {
        Label(refusal.message, systemImage: "exclamationmark.circle")
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.stateError)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SuiteSpacing.m)
            .padding(.vertical, SuiteSpacing.xs)
            .accessibilityIdentifier("halo.refusal")
    }
}
