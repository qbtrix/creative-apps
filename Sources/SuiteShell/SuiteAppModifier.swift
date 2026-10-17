// SuiteAppModifier.swift: `.suiteApp(_:host:)`, the scene modifier an app adds
// to its main window to take part in switching (blueprint 2.6). It hands the
// app's document host to the process's SuiteAppDelegate, which then accepts
// the hand-offs the app receives, settles them through a store over the
// support folder, sends the other documents to the host, and sets the window's
// app switcher from the same Switch To items as the menu.
import Foundation
import SuiteModel
import SuiteUI
import SwiftUI

extension Scene {
    @MainActor
    public func suiteApp(_ app: SuiteApp, host: any SuiteDocumentHost) -> some Scene {
        if let delegate = SuiteAppRegistry.delegate {
            let support = SuiteLocations.supportFolder(arguments: ProcessInfo.processInfo.arguments, home: NSHomeDirectory())
            delegate.app = app
            delegate.host = host
            delegate.receiver = StoreHandOffs(store: FileStore(folder: support), from: app, deliver: HandOffTransport.deliver)
        }
        return environment(\.suiteSwitcher, SuiteSwitcherBridge.state(current: app))
    }
}
