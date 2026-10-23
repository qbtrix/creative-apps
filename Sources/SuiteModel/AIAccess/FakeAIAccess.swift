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
    /// The demo client still to ask again after a Stop, as a real one would on its next call; once only.
    public private(set) var retryClient: String?

    public init(app: String, grants: AIAccessGrants = AIAccessGrants(), demoClient: String? = nil) {
        (self.app, self.grants, self.retryClient) = (app, grants, demoClient)
    }

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

    /// The chip's Stop button: the client is disconnected and an allow-once grant ends, so the next request asks;
    /// the demo client then sends that request, the first time only.
    public mutating func stop() {
        connectedClient = nil
        guard let client = retryClient else { return }
        retryClient = nil
        request(client: client)
    }

    /// Window > AI Access…'s revoke: forgets `client`'s grant here and disconnects it.
    public mutating func revoke(client: String) { grants.revoke(client: client, app: app); if connectedClient == client { connectedClient = nil } }
}
