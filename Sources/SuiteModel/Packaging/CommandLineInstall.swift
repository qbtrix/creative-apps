// CommandLineInstall.swift (cli-bundle CB-6): what Install Command-Line Tool… asks and says, decided here so
// SuiteShell's InstallCommandLineTool only shows the alerts and makes the link. The prompt names the link
// (`~/.local/bin/afterglow`) with Install and Cancel; only Install on AssistantConnect's `.link` plan writes; every
// outcome (linked, already linked, refused, a failed write) gets its own words. The home is `-SuiteHomeDir`'s value
// when a journey passes one. Pure values. Linux-safe.

/// Install Command-Line Tool…'s question, its one write and its answer.
public enum CommandLineInstall {
    /// The launch flag that points the install at another home (a journey's temp home).
    public static let homeFlag = "-SuiteHomeDir"
    public static let installTitle = "Install", cancelTitle = "Cancel", doneTitle = "OK"
    public static let installedTitle = "The command-line tool is installed"
    public static let alreadyTitle = "The command-line tool is already installed"
    public static let refusedTitle = "The command-line tool wasn't installed"
    public static let failedTitle = "Couldn't install the command-line tool"

    /// The alert's text and its buttons, first button first.
    public struct Message: Equatable, Sendable {
        public let title: String, message: String, buttons: [String]
    }

    /// The one link Install makes: a symlink at `at` pointing to `to`.
    public struct Link: Equatable, Sendable {
        public let at: String, to: String
    }

    /// `homeFlag`'s non-empty value in `arguments`, else `fallback`.
    public static func home(arguments: [String], fallback: String) -> String {
        guard let flag = arguments.firstIndex(of: homeFlag) else { return fallback }
        let next = arguments.index(after: flag)
        guard next < arguments.endIndex, !arguments[next].isEmpty else { return fallback }
        return arguments[next]
    }

    /// The question asked before anything is written, naming the link in `home`.
    public static func prompt(home: String, userHome: String) -> Message {
        let link = shown(AssistantConnect.linkPath(home: home), userHome: userHome)
        return Message(
            title: "Install the afterglow command-line tool?",
            message: "This makes \(link), a link to the afterglow inside AfterGlow.app, so a terminal or an AI "
                + "assistant can run afterglow by name. Nothing is written until you click Install.",
            buttons: [installTitle, cancelTitle])
    }

    /// The link to make for `plan`: only a `.link` plan the person confirmed; nil writes nothing.
    public static func linkToMake(_ plan: AssistantConnect.InstallPlan, confirmed: Bool) -> Link? {
        guard confirmed, case .link(let at, let to) = plan else { return nil }
        return Link(at: at, to: to)
    }

    /// What happened, for the alert after Install: `writeError` is why making the link failed, nil when it landed.
    public static func outcome(_ plan: AssistantConnect.InstallPlan, writeError: String?, userHome: String) -> Message {
        switch plan {
        case .link(let at, _):
            if let writeError { return Message(title: failedTitle, message: writeError, buttons: [doneTitle]) }
            let link = shown(at, userHome: userHome)
            return Message(
                title: installedTitle,
                message: "\(link) now runs the afterglow inside AfterGlow.app. If your shell can't find it, add "
                    + "~/.local/bin to your PATH.",
                buttons: [doneTitle])
        case .alreadyLinked(let at):
            return Message(
                title: alreadyTitle,
                message: "\(shown(at, userHome: userHome)) already links to this AfterGlow.app's afterglow, so nothing was changed.",
                buttons: [doneTitle])
        case .refuse(let reason):
            return Message(title: refusedTitle, message: reason, buttons: [doneTitle])
        }
    }

    /// `path` with the person's home as `~`.
    static func shown(_ path: String, userHome: String) -> String {
        let home = userHome.hasSuffix("/") ? String(userHome.dropLast()) : userHome
        guard !home.isEmpty, path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }
}
