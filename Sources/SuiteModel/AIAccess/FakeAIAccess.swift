// FakeAIAccess.swift (afterglow-mcp MC-1): the approval flow on a fake
// client for MC-12's sheet, chip and list. `-AIAccessDemoRequest` calls
// `request`; the sheet shows `pending`, the chip `connectedClient`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One app's approval state against a fake client.
public struct FakeAIAccess: Sendable {
    /// The client the journeys use.
    public static let demoClient = "Test Client"

    /// The app being driven, the remembered grants, the request the sheet shows, and the client in control.
    public let app: String
    public private(set) var grants: AIAccessGrants
    public private(set) var pending: AIAccessRequest?
    public private(set) var connectedClient: String?

    public init(app: String, grants: AIAccessGrants = AIAccessGrants()) { (self.app, self.grants) = (app, grants) }

    /// A client asks to drive the app: connects it when the grants allow, otherwise the sheet asks.
    public mutating func request(client: String, command: String? = nil) {
        if grants.allows(client: client, app: app, kind: "edit") == true {
            connectedClient = client
        } else {
            pending = AIAccessRequest(client: client, app: app, command: command)
        }
    }

    /// The user answers the sheet: a grant connects the client, a deny doesn't; either way the sheet closes.
    public mutating func decide(_ decision: AIAccessDecision) {
        guard let request = pending else { return }
        pending = nil
        if decision != .allowOnce { grants.record(decision, client: request.client, app: app) }
        if decision != .deny { connectedClient = request.client }
    }

    /// The chip's Stop button: the client is disconnected and an allow-once grant ends, so the next request asks.
    public mutating func stop() { connectedClient = nil }

    /// Window > AI Access…'s revoke: forgets `client`'s grant here and disconnects it.
    public mutating func revoke(client: String) { grants.revoke(client: client, app: app); if connectedClient == client { connectedClient = nil } }
}
