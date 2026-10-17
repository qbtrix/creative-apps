// SuiteAppDelegate.swift: the app delegate every suite app adopts (blueprint
// 2.6, hand-off transport). A hand-off file Launch Services opens here is
// decoded, accepted by the app's host, and settled with the state the host
// ends in. Any other document URL becomes an open hand-off to the host, so a
// file the app only routes never brings up a window of its own.
import AppKit
import SuiteModel

/// The process's suite delegate, set when it is created, so the `.suiteApp(_:host:)`
/// scene modifier can reach it from a scene.
@MainActor
public enum SuiteAppRegistry {
    public static var delegate: SuiteAppDelegate?
}

@MainActor
open class SuiteAppDelegate: NSObject, NSApplicationDelegate {
    /// The app's document host; nil until the app adopts `.suiteApp(_:host:)`.
    public var host: (any SuiteDocumentHost)?
    /// Decodes and settles the hand-off files this app receives.
    public var receiver: (any HandOffReceiving)?
    /// The app this delegate belongs to; a document URL is addressed to it.
    public var app: SuiteApp = .launcher

    public override init() {
        super.init()
        SuiteAppRegistry.delegate = self
    }

    open func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { await self.handle(url) }
        }
    }

    /// Hands one opened URL to the host. Public so an app's tests can run it without Launch Services.
    public func handle(_ url: URL) async {
        guard let host else { return }
        if url.pathExtension == "aghandoff" {
            await receiveHandOff(url, host: host)
        } else if let document = Self.document(for: url) {
            _ = try? await host.accept(HandOff(id: HandOff.newID(), from: .launcher, to: app, verb: .open,
                                               documents: [document], createdAt: Date()))
        }
    }

    private func receiveHandOff(_ url: URL, host: any SuiteDocumentHost) async {
        guard let receiver, let data = try? Data(contentsOf: url) else { return }
        guard let handOff = try? await receiver.receive(data, now: Date()) else { return }
        let state = (try? await host.accept(handOff)) ?? .returned
        try? await receiver.settle(id: handOff.id, as: state)
    }

    /// The document a URL names, typed by its extension and owned by the app that reads that type;
    /// nil for an extension no suite type claims.
    public static func document(for url: URL) -> SuiteDocumentRef? {
        let registry = SuiteTypeRegistry.standard
        guard let type = registry.type(forExtension: url.pathExtension.lowercased()) else { return nil }
        return SuiteDocumentRef(path: url.path, fileID: SuiteDocumentRef.fileID(forPath: url.path),
                                app: registry.defaultApp(for: type.id) ?? .launcher, type: type.id,
                                displayName: url.lastPathComponent)
    }
}
