// CommandLineInstall+Run.swift (cli-bundle CB-z): `help.install-cli`'s one implementation. The afterglow CLI's
// MCPConfig and the app's ShellHelpProvider both call `run`, so the in-app command and the CLI answer with the same
// plan: AssistantConnect.installPlan, and with confirm the link made for a `.link` plan only; a failed write is a
// refusal. SuiteKernel's SuiteHelpCatalog.planAnswer turns the result into the command's JSON. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension CommandLineInstall {
    /// `help.install-cli`'s answer: the plan (`link`, `alreadyLinked` or `refuse`), its paths or reason, and whether
    /// the link is in place.
    public struct InstallResult: Equatable, Sendable {
        public let plan: String, at: String?, to: String?, reason: String?, linked: Bool
        public init(plan: String, at: String?, to: String?, reason: String?, linked: Bool) {
            (self.plan, self.at, self.to, self.reason, self.linked) = (plan, at, to, reason, linked)
        }
    }

    /// The plan for `bundle`'s CLI in `home`, `existing(path)` being what sits at the link's path. Without `confirm`
    /// it writes nothing. With it, a `.link` plan calls `link(at, to)`; `alreadyLinked` and `refuse` write nothing,
    /// and a failed write is a refusal.
    public static func run(home: String, bundle: String, confirm: Bool, existing: (String) -> String?,
                           link: (String, String) throws -> Void = CommandLineInstall.makeLink) -> InstallResult {
        let plan = AssistantConnect.installPlan(home: home, bundle: bundle, existing: existing)
        guard let write = linkToMake(plan, confirmed: confirm) else { return result(plan) }
        do { try link(write.at, write.to) } catch {
            return result(.refuse(reason: "Couldn't make the link at \(write.at): \(error)"))
        }
        return InstallResult(plan: "link", at: write.at, to: write.to, reason: nil, linked: true)
    }

    /// A plan before anything is written: only `alreadyLinked` is in place.
    static func result(_ plan: AssistantConnect.InstallPlan) -> InstallResult {
        switch plan {
        case .link(let at, let to): InstallResult(plan: "link", at: at, to: to, reason: nil, linked: false)
        case .alreadyLinked(let at): InstallResult(plan: "alreadyLinked", at: at, to: nil, reason: nil, linked: true)
        case .refuse(let reason): InstallResult(plan: "refuse", at: nil, to: nil, reason: reason, linked: false)
        }
    }

    /// Makes `at`'s folder if needed, then a symlink at `at` to `to`. Throws when either fails, as when a file
    /// appeared at `at` since the plan was read.
    public static func makeLink(at: String, to: String) throws {
        let folder = URL(fileURLWithPath: at).deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: at, withDestinationPath: to)
    }

    /// What sits at `path`: a link's target, the path itself for any other file, nil for nothing.
    public static func linkTarget(_ path: String) -> String? {
        if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: path) { return target }
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}
