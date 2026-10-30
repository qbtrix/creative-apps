// MCPConfig.swift (cli-bundle CB-2; CB-4 fills AssistantConnect's bodies and makes the link): the CLI's answers to the suite's
// help.connect-assistant and help.install-cli. It finds AfterGlow.app from `--bundle` or from the CLI's own path at
// BundleLayout.cliPath, and answers through SuiteModel's AssistantConnect, so the sheet and the CLI read one text.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

/// The assistant commands' answers for one bundle and home.
public struct MCPConfig: Sendable, Hashable {
    /// AfterGlow.app, nil outside a bundle; the home whose `.local/bin` gets the link.
    public var bundle: String?, home: String
    public init(bundle: String?, home: String) { (self.bundle, self.home) = (bundle, home) }

    /// The bundle the CLI names: `--bundle`'s value, else the `.app` that holds `executable` at BundleLayout.cliPath.
    public static func bundle(flag: String?, executable: String) -> String? {
        if let flag, !flag.isEmpty { return flag.hasSuffix("/") ? String(flag.dropLast()) : flag }
        let suffix = "/" + BundleLayout.cliPath
        guard executable.hasSuffix(suffix) else { return nil }
        let app = String(executable.dropLast(suffix.count))
        return app.hasSuffix(".app") ? app : nil
    }

    /// `{command, json}` for the bundle; null outside one.
    public func connectAssistant() -> JSONValue {
        guard let bundle else { return .null }
        return .object(["command": .string(AssistantConnect.command(bundle: bundle)),
                        "json": .string(AssistantConnect.configJSON(bundle: bundle))])
    }

    /// The install plan for the bundle's CLI, `existing(path)` being what sits at the link's path; null outside a
    /// bundle. SuiteModel's CommandLineInstall.run decides it, as for the app's Help provider: without `confirm` it
    /// writes nothing, with it a `link` plan calls `link(at, to)`, and a failed write is a refusal.
    public func installCLI(confirm: Bool, existing: (String) -> String?,
                           link: (String, String) throws -> Void = CommandLineInstall.makeLink) -> JSONValue {
        guard let bundle else { return .null }
        let result = CommandLineInstall.run(home: home, bundle: bundle, confirm: confirm, existing: existing, link: link)
        return SuiteHelpCatalog.planAnswer(plan: result.plan, at: result.at, to: result.to, reason: result.reason,
                                           linked: result.linked)
    }

    /// This process's executable, symlinks resolved, so a run through `~/.local/bin/afterglow` finds the bundle.
    static func ownExecutable() -> String {
        guard let first = ProcessInfo.processInfo.arguments.first, first.hasPrefix("/") else { return "" }
        return URL(fileURLWithPath: first).resolvingSymlinksInPath().path
    }
}

/// The suite app's provider answers the assistant commands for the bundle this CLI runs from.
extension HelpReports {
    public var bundle: String? { MCPConfig.bundle(flag: nil, executable: MCPConfig.ownExecutable()) }
    var config: MCPConfig { MCPConfig(bundle: bundle, home: ProcessInfo.processInfo.environment["HOME"] ?? home) }
    public func connectAssistant() -> JSONValue { config.connectAssistant() }
    public func installCLI(confirm: Bool) -> JSONValue { config.installCLI(confirm: confirm, existing: CommandLineInstall.linkTarget) }
}
