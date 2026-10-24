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
    /// bundle. Without `confirm` it writes nothing. With it, a `link` plan calls `link(at, to)`, which makes the
    /// folder and the symlink; `alreadyLinked` and `refuse` write nothing, and a failed write is a refusal.
    public func installCLI(confirm: Bool, existing: (String) -> String?,
                           link: (String, String) throws -> Void = MCPConfig.makeLink) -> JSONValue {
        guard let bundle else { return .null }
        let plan = AssistantConnect.installPlan(home: home, bundle: bundle, existing: existing)
        guard confirm, case .link(let at, let to) = plan else { return Self.json(plan) }
        do { try link(at, to) } catch {
            return Self.json(.refuse(reason: "Couldn't make the link at \(at): \(error)"))
        }
        return .object(["plan": .string("link"), "at": .string(at), "to": .string(to), "linked": .bool(true)])
    }

    /// Makes `at`'s folder if needed, then a symlink at `at` to `to`. Throws when either fails, as when a file
    /// appeared at `at` since the plan was read.
    public static func makeLink(at: String, to: String) throws {
        let folder = URL(fileURLWithPath: at).deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: at, withDestinationPath: to)
    }

    /// A plan as the command's result: `plan`, its paths or reason, and whether the link is in place.
    static func json(_ plan: AssistantConnect.InstallPlan) -> JSONValue {
        switch plan {
        case .link(let at, let to):
            .object(["plan": .string("link"), "at": .string(at), "to": .string(to), "linked": .bool(false)])
        case .alreadyLinked(let at): .object(["plan": .string("alreadyLinked"), "at": .string(at), "linked": .bool(true)])
        case .refuse(let reason): .object(["plan": .string("refuse"), "reason": .string(reason), "linked": .bool(false)])
        }
    }

    /// This process's executable, symlinks resolved, so a run through `~/.local/bin/afterglow` finds the bundle.
    static func ownExecutable() -> String {
        guard let first = ProcessInfo.processInfo.arguments.first, first.hasPrefix("/") else { return "" }
        return URL(fileURLWithPath: first).resolvingSymlinksInPath().path
    }

    /// What sits at `path`: a link's target, the path itself for any other file, nil for nothing.
    static func linkTarget(_ path: String) -> String? {
        if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: path) { return target }
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}

/// The suite app's provider answers the assistant commands for the bundle this CLI runs from.
extension HelpReports {
    public var bundle: String? { MCPConfig.bundle(flag: nil, executable: MCPConfig.ownExecutable()) }
    var config: MCPConfig { MCPConfig(bundle: bundle, home: ProcessInfo.processInfo.environment["HOME"] ?? home) }
    public func connectAssistant() -> JSONValue { config.connectAssistant() }
    public func installCLI(confirm: Bool) -> JSONValue { config.installCLI(confirm: confirm, existing: MCPConfig.linkTarget) }
}
