// AssistantConnect.swift (cli-bundle CB-1 stubs, CB-4 bodies): the text Help > Connect an AI Assistant… shows
// and `afterglow run suite help.connect-assistant` returns, for the bundled CLI at BundleLayout.cliPath: the one
// command line an MCP client runs, the JSON block for clients that take one, and the plan for the
// `~/.local/bin/afterglow` link. Pure strings and a plan; it reads and writes nothing. Linux-safe.

/// The MCP client's command and config for the bundled `afterglow`, and the command-line install plan.
public enum AssistantConnect {
    /// The command an MCP client runs: the bundled CLI's quoted path, then `mcp`. Stub until CB-4.
    public static func command(bundle: String) -> String { "" }

    /// The client config block, `{"mcpServers": {"afterglow": {"command": …, "args": ["mcp"]}}}`. Stub until CB-4.
    public static func configJSON(bundle: String) -> String { "" }

    /// What Install Command-Line Tool… does at `<home>/.local/bin/afterglow`.
    public enum InstallPlan: Equatable, Sendable {
        /// Make a symlink at `at` pointing to `to`, the bundled CLI.
        case link(at: String, to: String)
        /// The link at this path already points to the bundled CLI.
        case alreadyLinked(String)
        /// Write nothing, for this reason (a file or link that isn't ours).
        case refuse(reason: String)
    }

    /// The plan for `home`'s link to `bundle`'s CLI; `existing(path)` is the link's target, or nil when nothing is
    /// there. Stub until CB-4: it refuses, so nothing is written.
    public static func installPlan(home: String, bundle: String, existing: (String) -> String?) -> InstallPlan {
        .refuse(reason: "Not built yet.")
    }
}
