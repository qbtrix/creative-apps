// SuiteFileDrop.swift (file-flow SF-2 on the fakes, SF-3 mark, SF-8 live): a window takes dropped files and
// folders. The kernel's drop rule (DropPlan) gives one action per file, worked out with the bridge's
// registry, and the window performs them in one step. While files hover, a mark at the window's bottom says
// what the first one will do: "Open in Halo", "Place in Sunset", or why it can't open.
import Foundation
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Takes file drops for `app`: each file opens, is placed into the open document (`documentName`), is
    /// handed to the app that reads it, or is refused, and `perform` gets every action at once.
    public func suiteFileDrop(_ app: SuiteApp, bridge: SuiteDocumentsBridge, hasDocument: Bool,
                              places: Set<String>, documentName: String? = nil,
                              perform: @escaping ([DropAction]) -> Void) -> some View {
        let registry = bridge.registry
        let plan: ([String]) -> [DropAction] = { paths in
            DropPlan.plan(paths, into: app.rawValue, hasDocument: hasDocument, places: places,
                          readers: { @Sendable ext in SuiteDocumentsBridge.readers(in: registry, ofExtension: ext) })
        }
        return modifier(SuiteFileDropModifier(app: app, documentName: documentName, plan: plan, perform: perform))
    }
}

/// What the drop mark says about a planned drop.
public enum SuiteDropMark {
    /// The first action's sentence: "Open in <app>", "Place in <document>", or the refusal's reason.
    public static func sentence(for actions: [DropAction], app: SuiteApp, documentName: String? = nil) -> String? {
        switch actions.first {
        case nil: nil
        case .open: "Open in \(app.displayName)"
        case .place: "Place in \(documentName ?? "the document")"
        case .handOff(_, let reader): "Open in \(SuiteApp(rawValue: reader)?.displayName ?? reader)"
        case .refuse(_, let reason): reason
        }
    }

    /// Whether the first file is refused, so the mark shows the refusal.
    public static func refuses(_ actions: [DropAction]) -> Bool {
        if case .refuse = actions.first { true } else { false }
    }
}

/// The mark: the sentence on a glass panel, one accessibility element labelled with it.
struct SuiteDropMarkView: View {
    let sentence: String
    let refused: Bool

    var body: some View {
        GlassPanel {
            Label(sentence, systemImage: refused ? "nosign" : "arrow.down.doc")
                .font(SuiteFont.body)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sentence)
        .accessibilityIdentifier(SuiteFileControlID.dropMark)
    }
}

private struct SuiteFileDropModifier: ViewModifier {
    let app: SuiteApp
    let documentName: String?
    let plan: ([String]) -> [DropAction]
    let perform: ([DropAction]) -> Void
    @State private var hovering: [DropAction] = []

    func body(content: Content) -> some View {
        content
            .onDrop(of: [.fileURL], delegate: SuiteFileDropDelegate(plan: plan, perform: perform, hovering: $hovering))
            .overlay(alignment: .bottom) {
                if let sentence = SuiteDropMark.sentence(for: hovering, app: app, documentName: documentName) {
                    SuiteDropMarkView(sentence: sentence, refused: SuiteDropMark.refuses(hovering))
                        .padding(SuiteSpacing.l)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// Plans the hovering files once when they enter (the mark changes once), clears the mark when they leave,
/// and on release plans and performs them.
private struct SuiteFileDropDelegate: DropDelegate {
    let plan: ([String]) -> [DropAction]
    let perform: ([DropAction]) -> Void
    @Binding var hovering: [DropAction]

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.fileURL]) }

    func dropEntered(info: DropInfo) {
        let plan = self.plan, hovering = $hovering
        Self.paths(info) { paths in hovering.wrappedValue = plan(paths) }
    }

    func dropExited(info: DropInfo) { hovering = [] }

    func performDrop(info: DropInfo) -> Bool {
        hovering = []
        let plan = self.plan, perform = self.perform
        Self.paths(info) { paths in
            let actions = plan(paths)
            if !actions.isEmpty { perform(actions) }
        }
        return true
    }

    /// The dropped file URLs' paths, in order, handed to `done` on the main actor.
    private static func paths(_ info: DropInfo, _ done: @escaping @MainActor ([String]) -> Void) {
        let providers = info.itemProviders(for: [.fileURL])
        Task { @MainActor in
            var paths: [String] = []
            for provider in providers {
                if let url = await fileURL(provider), url.isFileURL { paths.append(url.path) }
            }
            done(paths)
        }
    }

    private static func fileURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
        }
    }
}
