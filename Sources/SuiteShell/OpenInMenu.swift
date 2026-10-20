// OpenInMenu.swift (file-flow SF-2 on the fakes, SF-3 views): File > Open Recent ▸ and Open In ▸, after the
// app's Open… item. Open Recent lists the app's files newest first with Clear Menu, or a disabled
// "No Recent Files". Open In lists the open document's other readers, or stays off with its reason: "Open a
// document first." with none open, else the routing slot's sentence. `SuiteFileMenu` is what both show.
import SuiteKernel
import SuiteModel
import SwiftUI

/// The `suite.file.*` accessibility identifiers of the file-flow controls.
public enum SuiteFileControlID {
    public static let openRecent = "suite.file.open-recent"
    public static let noRecent = "suite.file.no-recent"
    public static let clearRecent = "suite.file.clear-recent"
    public static let openIn = "suite.file.open-in"
    public static let dropMark = "suite.file.drop-mark"

    /// One recent file's row, by its file id.
    public static func recent(_ fileID: String) -> String { "suite.file.recent.\(fileID)" }
    /// One Open In target's row.
    public static func openIn(_ app: SuiteApp) -> String { "suite.file.open-in.\(app.rawValue)" }
}

/// What File > Open Recent ▸ and Open In ▸ show for one app and its open document.
@MainActor public struct SuiteFileMenu {
    public static let noRecentFiles = "No Recent Files"
    /// Open In's reason while no document is open.
    public static let openFirst = "Open a document first."

    /// The app's recent files, newest first.
    public let recents: [RecentFileEntry]
    /// The apps Open In hands the document to; empty when it is off.
    public let openInTargets: [SuiteApp]
    /// Why Open In is off, or nil when it lists targets.
    public let openInHelp: String?

    public var recentsEmpty: Bool { recents.isEmpty }

    public init(app: SuiteApp, bridge: SuiteDocumentsBridge, document: SuiteDocumentRef? = nil) {
        recents = bridge.recents(for: app)
        guard let document else {
            openInTargets = []; openInHelp = Self.openFirst
            return
        }
        let targets = bridge.openInTargets(for: document)
        openInTargets = targets
        openInHelp = targets.isEmpty ? (bridge.openInRefusal(for: document)?.message ?? Self.openFirst) : nil
    }
}

/// File > Open Recent ▸ and Open In ▸ for one app, read from its documents bridge.
public struct SuiteFileCommands: Commands {
    private let app: SuiteApp
    private let bridge: SuiteDocumentsBridge
    private let document: SuiteDocumentRef?

    /// `document` is the app's open document, which Open In hands to another app.
    public init(app: SuiteApp, bridge: SuiteDocumentsBridge, document: SuiteDocumentRef? = nil) {
        self.app = app; self.bridge = bridge; self.document = document
    }

    /// Open In's reason while no document is handed to the menu.
    public static let openInHelp = SuiteFileMenu.openFirst

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            let menu = SuiteFileMenu(app: app, bridge: bridge, document: document)
            Menu("Open Recent") {
                if menu.recentsEmpty {
                    Button(SuiteFileMenu.noRecentFiles) {}
                        .disabled(true).accessibilityIdentifier(SuiteFileControlID.noRecent)
                } else {
                    ForEach(menu.recents, id: \.fileID) { file in
                        Button(file.name) { reopen(file.fileID) }
                            .help(file.path).accessibilityIdentifier(SuiteFileControlID.recent(file.fileID))
                    }
                    Divider()
                    Button("Clear Menu") { clear() }
                        .accessibilityIdentifier(SuiteFileControlID.clearRecent)
                }
            }
            .accessibilityIdentifier(SuiteFileControlID.openRecent)
            Menu("Open In") {
                ForEach(menu.openInTargets, id: \.self) { target in
                    Button(target.displayName) { openIn(target) }
                        .accessibilityIdentifier(SuiteFileControlID.openIn(target))
                }
            }
            .disabled(menu.openInTargets.isEmpty)
            .help(menu.openInHelp ?? "")
            .accessibilityIdentifier(SuiteFileControlID.openIn)
        }
    }

    private func reopen(_ fileID: String) {
        let bridge = self.bridge
        Task { try? await bridge.reopen(fileID) }
    }

    private func clear() {
        let bridge = self.bridge, app = self.app
        Task { await bridge.clear(app: app) }
    }

    private func openIn(_ target: SuiteApp) {
        guard let document else { return }
        let bridge = self.bridge
        Task { try? await bridge.openIn(document, app: target) }
    }
}
