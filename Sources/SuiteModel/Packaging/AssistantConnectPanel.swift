// AssistantConnectPanel.swift (cli-bundle CB-5): what Help > Connect an AI Assistant…'s sheet shows. A stub: the
// next commit reads AssistantConnect and says why each control can't act. Linux-safe.

/// The Connect an AI Assistant sheet's text and which of its buttons can act.
public struct AssistantConnectPanel: Equatable, Sendable {
    public let command: String, configJSON: String
    public let installUnavailable: String?

    public static let notBuilt = "The bundled command-line tool isn't in this build yet."
    public static let nothingToCopy = "There's nothing to copy until this build bundles the command-line tool."
    public static let installNotBuilt = "Installing the command-line tool isn't in this build yet."

    public init(bundle: String) { self.init(command: "", configJSON: "", installUnavailable: nil) }

    public init(command: String, configJSON: String, installUnavailable: String? = nil) {
        (self.command, self.configJSON, self.installUnavailable) = ("", "", nil)
    }

    public var shownCommand: String { "" }
    public var shownConfig: String { "" }
    public var copyCommandUnavailable: String? { nil }
    public var copyConfigUnavailable: String? { nil }

    public static func bundle(containing path: String) -> String? { nil }
}
