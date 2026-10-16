// NewDocumentPreset.swift: one way to start a new document, as the home
// and the File > New menus offer it. Foundation free, Linux-safe, Sendable.

/// One way to start a new document in one app.
public struct NewDocumentPreset: Hashable, Codable, Sendable {
    public var id: String               // "flare.vertical"
    public var app: SuiteApp
    public var title: String            // "Vertical 9:16"
    public var detail: String           // "1080 × 1920, 30 fps"
    public var parameters: [String: String]   // read by the app, e.g. ["width": "1080"]
    public init(id: String, app: SuiteApp, title: String, detail: String, parameters: [String: String] = [:]) {
        self.id = id; self.app = app; self.title = title; self.detail = detail; self.parameters = parameters
    }
}
