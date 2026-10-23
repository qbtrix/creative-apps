// AssistantConnect.swift (cli-bundle CB-1 stubs, CB-4 bodies): the text Help > Connect an AI Assistant… shows
// and `afterglow run suite help.connect-assistant` returns, for the bundled CLI at BundleLayout.cliPath: the one
// command line an MCP client runs, the JSON block for clients that take one, and the plan for the
// `~/.local/bin/afterglow` link. Pure strings and a plan; it reads and writes nothing. Linux-safe.

/// The MCP client's command and config for the bundled `afterglow`, and the command-line install plan.
public enum AssistantConnect {
    /// The bundled CLI inside `bundle`.
    static func cli(bundle: String) -> String {
        (bundle.hasSuffix("/") ? String(bundle.dropLast()) : bundle) + "/" + BundleLayout.cliPath
    }

    /// The command an MCP client runs: the bundled CLI's path in double quotes (a shell's `\`, `"`, `$` and
    /// backtick escaped, so a folder with spaces or quotes stays one word), then `mcp`.
    public static func command(bundle: String) -> String {
        "\"\(shellQuoted(cli(bundle: bundle)))\" mcp"
    }

    /// The client config block, `{"mcpServers": {"afterglow": {"command": …, "args": ["mcp"]}}}`: the stdio server.
    public static func configJSON(bundle: String) -> String {
        """
        {
          "mcpServers": {
            "afterglow": {
              "command": "\(jsonEscaped(cli(bundle: bundle)))",
              "args": ["mcp"]
            }
          }
        }
        """
    }

    /// What Install Command-Line Tool… does at `<home>/.local/bin/afterglow`.
    public enum InstallPlan: Equatable, Sendable {
        /// Make a symlink at `at` pointing to `to`, the bundled CLI.
        case link(at: String, to: String)
        /// The link at this path already points to the bundled CLI.
        case alreadyLinked(String)
        /// Write nothing, for this reason (a file or link that isn't ours).
        case refuse(reason: String)
    }

    /// The link's path in `home`.
    public static func linkPath(home: String) -> String {
        (home.hasSuffix("/") ? String(home.dropLast()) : home) + "/.local/bin/afterglow"
    }

    /// The plan for `home`'s link to `bundle`'s CLI; `existing(path)` is the link's target, the path itself for
    /// any other file, or nil when nothing is there. Only an empty path is linked; it never overwrites.
    public static func installPlan(home: String, bundle: String, existing: (String) -> String?) -> InstallPlan {
        let at = linkPath(home: home), cli = cli(bundle: bundle)
        guard let target = existing(at) else { return .link(at: at, to: cli) }
        if target == cli { return .alreadyLinked(at) }
        return .refuse(reason: foreign(at: at, target: target))
    }

    /// Why a file at `at` stays: what it is, and what to do.
    static func foreign(at: String, target: String) -> String {
        let what = target == at || target.isEmpty ? "a file that isn't AfterGlow's link" : "a link to \(target)"
        return "\(at) is already \(what), so nothing was changed. Move it away and try again, or run the bundled afterglow by its full path."
    }

    /// `text` safe inside a shell's double quotes.
    static func shellQuoted(_ text: String) -> String {
        var out = ""
        for character in text {
            if "\\\"$`".contains(character) { out.append("\\") }
            out.append(character)
        }
        return out
    }

    /// `text` as the inside of a JSON string: quote, backslash and control characters escaped.
    static func jsonEscaped(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
