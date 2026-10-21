// SuiteFileDrop.swift (file-flow SF-2 on the fakes, SF-3 mark, SF-8 live): a window takes dropped files and
// folders. The kernel's drop rule (DropPlan) gives one action per file, worked out with the bridge's
// registry, and the window performs them in one step. While files hover, a mark at the window's bottom says
// what the first one will do: "Open in Halo", "Place in Sunset", or why it can't open. The mark stays a
// moment after the release, so a refused file is read, not silently ignored.
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

/// What the drop mark shows: the planned actions of the files hovering now, or of the last drop for
/// `linger` after it. A plan that lands after its files left (a stale session) is dropped.
@MainActor @Observable final class SuiteDropHover {
    /// How long the mark stays after a drop.
    static let linger: Duration = .seconds(3)

    private(set) var actions: [DropAction] = []
    @ObservationIgnored private var session = 0

    /// A new hover begins; its plan comes in with `planned(_:for:)`.
    func begin() -> Int {
        session += 1
        return session
    }

    /// The hover `session`'s plan, unless another hover or the exit came since.
    func planned(_ actions: [DropAction], for session: Int) {
        if session == self.session { self.actions = actions }
    }

    /// The files left without a drop.
    func exit() {
        session += 1
        actions = []
    }

    /// The files were dropped: the mark keeps saying what happened, then clears unless a new hover began.
    func dropped(_ actions: [DropAction], linger: Duration = SuiteDropHover.linger) {
        session += 1
        let session = self.session
        self.actions = actions
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: linger)
            if let self, self.session == session { self.actions = [] }
        }
    }
}

struct SuiteFileDropModifier: ViewModifier {
    let app: SuiteApp
    let documentName: String?
    let plan: ([String]) -> [DropAction]
    let perform: ([DropAction]) -> Void
    @State var hover = SuiteDropHover()

    func body(content: Content) -> some View {
        content
            .onDrop(of: [.fileURL], delegate: SuiteFileDropDelegate(plan: plan, perform: perform, hover: hover))
            .overlay(alignment: .bottom) {
                if let sentence = SuiteDropMark.sentence(for: hover.actions, app: app, documentName: documentName) {
                    SuiteDropMarkView(sentence: sentence, refused: SuiteDropMark.refuses(hover.actions))
                        .padding(SuiteSpacing.l)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// Plans the hovering files once when they enter (the mark changes once), clears the mark when they leave,
/// and on release plans and performs them, the mark saying what the drop did.
private struct SuiteFileDropDelegate: DropDelegate {
    let plan: ([String]) -> [DropAction]
    let perform: ([DropAction]) -> Void
    let hover: SuiteDropHover

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.fileURL]) }

    func dropEntered(info: DropInfo) {
        let plan = self.plan, hover = self.hover
        let session = hover.begin()
        Self.paths(info) { paths in hover.planned(plan(paths), for: session) }
    }

    func dropExited(info: DropInfo) { hover.exit() }

    func performDrop(info: DropInfo) -> Bool {
        let plan = self.plan, perform = self.perform, hover = self.hover
        Self.paths(info) { paths in
            let actions = plan(paths)
            hover.dropped(actions)
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
