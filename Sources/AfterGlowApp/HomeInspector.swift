// HomeInspector.swift: the home's inspector (blueprint suite.md 6.1, HM-2b).
// No selection: the one sentence. A selected card: InspectorHeader (name; app,
// last used, path), then Open, Open In ▸ (disabled until recents-open-in
// routes a file), Show in Finder, Locate… on a missing card and Remove from
// Recents, each an InspectorAction listed as afterglow.home.inspector.<name>.
// Open waits on `sending` as the New tiles do.
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI

struct HomeInspector: View {
    let model: HomeModel
    let services: SuiteServices

    private var card: RecentCard? {
        model.selection.flatMap { id in model.state.cards.first { $0.item.ref.fileID == id } }
    }

    var body: some View {
        if let card {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                InspectorHeader(card.item.ref.displayName, facts: [
                    InspectorFact("App", card.item.ref.app.displayName),
                    InspectorFact("Last used", card.age),
                    InspectorFact("Path", card.item.ref.path),
                ])
                VStack(spacing: SuiteSpacing.s) {  // InspectorHeader insets itself by m
                    ForEach(actions(card)) { InspectorAction($0) }
                }
                .padding(.horizontal, SuiteSpacing.m)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("Select a recent item to see its details.")
                .foregroundStyle(SuiteColor.textSecondary)
                .padding(SuiteSpacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func actions(_ card: RecentCard) -> [ToolbarAction] {
        let ref = card.item.ref
        let missing = card.isMissing ? SuiteError.fileMissing(name: ref.displayName).message : nil
        let openIn = services.pending["routing"] ?? SuiteServices.notConnected("routing")
            ?? SuiteIdentity.notConnected("recents-open-in")
        var list = [
            ToolbarAction("Open", systemImage: "arrow.up.forward.app", unavailableHelp: missing ?? services.pending["sending"],
                          identifier: "afterglow.home.inspector.open") {
                Task { await model.openSelection(now: Date()) }
            },
            ToolbarAction("Open In", systemImage: "square.and.arrow.up.on.square", unavailableHelp: openIn,
                          identifier: "afterglow.home.inspector.openIn"),
            ToolbarAction("Show in Finder", systemImage: "folder", unavailableHelp: missing,
                          identifier: "afterglow.home.inspector.showInFinder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: ref.path)])
            },
        ]
        if card.isMissing {
            list.append(ToolbarAction("Locate…", systemImage: "magnifyingglass", identifier: "afterglow.home.inspector.locate") {
                Self.locate(ref, model: model)
            })
        }
        list.append(ToolbarAction("Remove from Recents", systemImage: "minus.circle",
                                  identifier: "afterglow.home.inspector.remove") {
            Task { await model.removeSelection(now: Date()) }
        })
        return list
    }

    /// Locate…: the person picks where the file went; the card re-points to
    /// it. The inspector and the missing-file notice both call it.
    static func locate(_ ref: SuiteDocumentRef, model: HomeModel) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Locate"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.locate(ref.fileID, newPath: url.path(percentEncoded: false), now: Date()) }
    }
}
