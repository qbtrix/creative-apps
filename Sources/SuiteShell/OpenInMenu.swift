// OpenInMenu.swift (file-flow SF-2 on the fakes, SF-3 views): File > Open Recent ▸ and Open In ▸, after the
// app's Open… item. Open Recent lists the app's files newest first with Clear Menu, or a disabled
// "No Recent Files". Open In stays off with its reason until an adopting app gives it the open document.
import SuiteModel
import SwiftUI

/// File > Open Recent ▸ and Open In ▸ for one app, read from its documents bridge.
public struct SuiteFileCommands: Commands {
    private let app: SuiteApp
    private let bridge: SuiteDocumentsBridge

    public init(app: SuiteApp, bridge: SuiteDocumentsBridge) {
        self.app = app; self.bridge = bridge
    }

    /// Open In's reason while no document is handed to the menu.
    public static let openInHelp = "Open a document first."

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Menu("Open Recent") {
                let files = bridge.recents(for: app)
                if files.isEmpty {
                    Button("No Recent Files") {}.disabled(true)
                } else {
                    ForEach(files, id: \.fileID) { file in
                        Button(file.name) { reopen(file.fileID) }.help(file.path)
                    }
                    Divider()
                    Button("Clear Menu") { clear() }
                }
            }
            Menu("Open In") {}
                .disabled(true).help(Self.openInHelp)
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
}
