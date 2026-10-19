// AIAccessPrompt.swift (afterglow-mcp MC-12): the copy of the approval sheet, the
// chip and Window > AI Access…, and the `-AIAccessDemoRequest <client>` launch hook.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The copy the AI access views show, and the demo launch hook.
public enum AIAccessPrompt {
    /// The launch argument a journey passes, followed by the client's name.
    public static let demoArgument = "-AIAccessDemoRequest"
    /// The Window menu item and its window; the sheet's, chip's and rows' buttons; the empty list.
    public static let menuTitle = "AI Access…", windowTitle = "AI Access"
    public static let allowOnce = "Allow Once", alwaysAllow = "Always Allow", deny = "Deny", stop = "Stop", revoke = "Revoke"
    public static let emptyTitle = "No AI Clients", emptyMessage = "Clients you always allow or deny show up here."

    /// The client named after `demoArgument`, or nil when the flag is absent or has no name after it.
    public static func demoClient(in arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(of: demoArgument), flag + 1 < arguments.count else { return nil }
        let client = arguments[flag + 1]
        return client.allSatisfy(\.isWhitespace) || client.hasPrefix("-") ? nil : client
    }

    /// The sheet's question, naming the client as an AI assistant and the app.
    public static func title(_ request: AIAccessRequest) -> String {
        "Allow the AI assistant “\(request.client)” to work in \(request.app)?"
    }

    /// The sheet's explanation: what the client may touch (the named document, or the app's documents when the
    /// window has none), how to stop it, and the command it sent when there is one.
    public static func message(_ request: AIAccessRequest) -> String {
        let document = request.document.flatMap { $0.isEmpty ? nil : $0 }
        let scope = document.map { "read and edit “\($0)”" } ?? "open, read and edit your documents in \(request.app)"
        let base = "It can \(scope) until you click \(stop) in the title bar. Change this later in Window > \(windowTitle)."
        guard let command = request.command, !command.isEmpty else { return base }
        return base + " It asked to run “\(command)”."
    }

    /// The line under the sheet's message telling the two allows apart.
    public static func choiceHelp(_ request: AIAccessRequest) -> String {
        "\(allowOnce) lasts until “\(request.client)” disconnects. \(alwaysAllow) remembers “\(request.client)” for \(request.app)."
    }

    /// The chip's label while `client` drives the window.
    public static func chip(client: String) -> String { "Controlled by \(client)" }

    /// A list row's status for a remembered decision.
    public static func status(_ decision: AIAccessDecision) -> String {
        switch decision {
        case .allowOnce: "Allowed once"
        case .alwaysForClient: "Always allowed"
        case .deny: "Denied"
        }
    }
}
