// CommandLineInstallRunTests.swift (cli-bundle CB-z): `help.install-cli`'s one implementation, which the CLI and
// the app's Help provider both call. A confirmed `.link` plan makes the folder and the symlink; without confirm
// nothing is written; our own link is already linked; a foreign file is refused; a failed write is a refusal with
// `linked` false. Linux-safe; the real-file test works in a temp home.
import Foundation
import SuiteModel
import Testing

@Suite struct CommandLineInstallRunTests {
    static let bundle = "/Applications/AfterGlow.app"
    static let cli = bundle + "/Contents/Helpers/afterglow"
    static let home = "/Users/tester"
    static let at = home + "/.local/bin/afterglow"

    /// Runs the install over a fake file system: `existing` answers, `made` records each link asked for.
    static func run(confirm: Bool, existing: String?, made: inout [String],
                    fail: Bool = false) -> CommandLineInstall.InstallResult {
        var asked = [String]()
        let result = CommandLineInstall.run(home: home, bundle: bundle, confirm: confirm, existing: { _ in existing }) {
            if fail { throw CocoaError(.fileWriteNoPermission) }
            asked.append($0 + " -> " + $1)
        }
        made += asked
        return result
    }

    @Test func withoutConfirmNothingIsWritten() {
        var made = [String]()
        let result = Self.run(confirm: false, existing: nil, made: &made)
        #expect(result == .init(plan: "link", at: Self.at, to: Self.cli, reason: nil, linked: false))
        #expect(made.isEmpty)
    }

    @Test func confirmMakesTheLink() {
        var made = [String]()
        let result = Self.run(confirm: true, existing: nil, made: &made)
        #expect(result == .init(plan: "link", at: Self.at, to: Self.cli, reason: nil, linked: true))
        #expect(made == ["\(Self.at) -> \(Self.cli)"])
    }

    @Test func ourOwnLinkIsAlreadyLinked() {
        var made = [String]()
        let result = Self.run(confirm: true, existing: Self.cli, made: &made)
        #expect(result == .init(plan: "alreadyLinked", at: Self.at, to: nil, reason: nil, linked: true))
        #expect(made.isEmpty)
    }

    @Test func aForeignFileIsRefused() {
        var made = [String]()
        let result = Self.run(confirm: true, existing: "/opt/homebrew/bin/afterglow", made: &made)
        #expect(result.plan == "refuse" && !result.linked && result.at == nil && result.to == nil)
        #expect(!(result.reason ?? "").isEmpty)
        #expect(made.isEmpty, "confirm never writes over a foreign file")
    }

    @Test func aFailedWriteIsARefusal() {
        var made = [String]()
        let result = Self.run(confirm: true, existing: nil, made: &made, fail: true)
        #expect(result.plan == "refuse" && !result.linked)
        #expect(result.reason?.hasPrefix("Couldn't make the link at \(Self.at)") == true)
    }

    @Test func makesARealLinkOnceInATempHome() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("afterglow-run-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: home) }
        let at = home + "/.local/bin/afterglow"
        let plan = CommandLineInstall.run(home: home, bundle: Self.bundle, confirm: false, existing: CommandLineInstall.linkTarget)
        #expect(plan.plan == "link" && !plan.linked)
        #expect(CommandLineInstall.linkTarget(at) == nil, "the plan alone writes nothing")
        let made = CommandLineInstall.run(home: home, bundle: Self.bundle, confirm: true, existing: CommandLineInstall.linkTarget)
        #expect(made.linked)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: at) == Self.cli)
        let again = CommandLineInstall.run(home: home, bundle: Self.bundle, confirm: true, existing: CommandLineInstall.linkTarget)
        #expect(again.plan == "alreadyLinked" && again.linked)
    }

    @Test func aPlainFileIsItsOwnTarget() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("afterglow-file-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: folder) }
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let file = folder + "/afterglow"
        #expect(FileManager.default.createFile(atPath: file, contents: Data("x".utf8)))
        #expect(CommandLineInstall.linkTarget(file) == file)
        #expect(CommandLineInstall.linkTarget(folder + "/none") == nil)
    }
}
