// SuiteFileDrop.swift (file-flow SF-2 on the fakes, SF-3 mark, SF-8 live): a window takes dropped files and
// folders. The kernel's drop rule (DropPlan) gives one action per file, worked out with the bridge's
// registry, and the window performs them in one step.
import Foundation
import SuiteKernel
import SuiteModel
import SwiftUI

extension View {
    /// Takes file drops for `app`: each file opens, is placed into the open document, is handed to the app
    /// that reads it, or is refused, and `perform` gets every action at once.
    public func suiteFileDrop(_ app: SuiteApp, bridge: SuiteDocumentsBridge, hasDocument: Bool,
                              places: Set<String>, perform: @escaping ([DropAction]) -> Void) -> some View {
        let registry = bridge.registry
        return dropDestination(for: URL.self) { urls, _ in
            let paths = urls.filter(\.isFileURL).map(\.path)
            guard !paths.isEmpty else { return false }
            let actions = DropPlan.plan(paths, into: app.rawValue, hasDocument: hasDocument, places: places,
                                        readers: { @Sendable ext in SuiteDocumentsBridge.readers(in: registry, ofExtension: ext) })
            perform(actions)
            return actions.contains { if case .refuse = $0 { false } else { true } }
        }
    }
}
