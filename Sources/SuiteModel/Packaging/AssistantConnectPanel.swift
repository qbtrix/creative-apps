// AssistantConnectPanel.swift (cli-bundle CB-5): what Help > Connect an AI Assistant…'s sheet shows, decided here
// so the SuiteUI sheet only draws it. The command and the JSON block come from AssistantConnect for the running
// AfterGlow.app; a Copy whose text is empty is disabled with its reason, and Install Command-Line Tool… runs for a
// known bundle (CB-6, CommandLineInstall) and is disabled, saying why, without one (no dead controls). Pure values.
// Linux-safe.

/// The Connect an AI Assistant sheet's text and which of its buttons can act.
public struct AssistantConnectPanel: Equatable, Sendable {
    /// The command line an MCP client runs, and the client config block; "" until the bundle's text is built.
    public let command: String, configJSON: String
    /// Why Install Command-Line Tool… can't run yet; nil once it can.
    public let installUnavailable: String?

    /// Shown in place of an empty command or config.
    public static let notBuilt = "The bundled command-line tool isn't in this build yet."
    /// Copy's reason while there is nothing to copy.
    public static let nothingToCopy = "There's nothing to copy until this build bundles the command-line tool."
    /// Install's reason without a bundle to link to, or a host that can install.
    public static let installNeedsBundle = "Installing the command-line tool needs AfterGlow.app; this copy isn't running from it."

    /// The sheet for the AfterGlow.app at `bundle`, reading AssistantConnect.
    public init(bundle: String) {
        self.init(
            command: AssistantConnect.command(bundle: bundle), configJSON: AssistantConnect.configJSON(bundle: bundle),
            installUnavailable: nil)
    }

    /// The sheet over given text.
    public init(command: String, configJSON: String, installUnavailable: String? = Self.installNeedsBundle) {
        (self.command, self.configJSON, self.installUnavailable) = (command, configJSON, installUnavailable)
    }

    /// What the command and config boxes show: the text, or why there is none.
    public var shownCommand: String { command.isEmpty ? Self.notBuilt : command }
    public var shownConfig: String { configJSON.isEmpty ? Self.notBuilt : configJSON }
    /// Why each Copy is disabled; nil when it copies.
    public var copyCommandUnavailable: String? { command.isEmpty ? Self.nothingToCopy : nil }
    public var copyConfigUnavailable: String? { configJSON.isEmpty ? Self.nothingToCopy : nil }

    /// The AfterGlow.app that holds `path` (the running bundle's path, or a helper app inside it); nil outside one.
    public static func bundle(containing path: String) -> String? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard let index = parts.firstIndex(of: "AfterGlow.app") else { return nil }
        return "/" + parts[...index].joined(separator: "/")
    }
}
