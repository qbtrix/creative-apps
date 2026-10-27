// CommandLineInstallTests.swift (cli-bundle CB-6): Install Command-Line Tool… asks first, naming the link it makes;
// only Install on a plan that links writes, Cancel and a plan that refuses or is already linked write nothing; each
// outcome says what happened; `-SuiteHomeDir` picks the home a journey uses. Linux-safe.
import SuiteModel
import Testing

@Suite struct CommandLineInstallTests {
    static let bundle = "/Applications/AfterGlow.app"
    static let home = "/Users/tester"
    static let cli = bundle + "/Contents/Helpers/afterglow"

    @Test func homeComesFromTheLaunchFlagWhenGiven() {
        #expect(CommandLineInstall.home(arguments: ["app", "-SuiteHomeDir", "/tmp/h"], fallback: Self.home) == "/tmp/h")
        #expect(CommandLineInstall.home(arguments: ["app"], fallback: Self.home) == Self.home)
        #expect(CommandLineInstall.home(arguments: ["app", "-SuiteHomeDir"], fallback: Self.home) == Self.home)
        #expect(CommandLineInstall.home(arguments: ["app", "-SuiteHomeDir", ""], fallback: Self.home) == Self.home)
    }

    @Test func promptNamesTheLinkWithInstallAndCancel() {
        let prompt = CommandLineInstall.prompt(home: Self.home, userHome: Self.home)
        #expect(prompt.message.contains("~/.local/bin/afterglow"))
        #expect(prompt.buttons == ["Install", "Cancel"])
        // Another home (a journey's temp home) is named in full.
        #expect(CommandLineInstall.prompt(home: "/tmp/h", userHome: Self.home).message.contains("/tmp/h/.local/bin/afterglow"))
    }

    @Test func onlyAConfirmedLinkPlanWrites() {
        let plan = AssistantConnect.InstallPlan.link(at: Self.home + "/.local/bin/afterglow", to: Self.cli)
        let write = CommandLineInstall.linkToMake(plan, confirmed: true)
        #expect(write?.at == Self.home + "/.local/bin/afterglow" && write?.to == Self.cli)
        #expect(CommandLineInstall.linkToMake(plan, confirmed: false) == nil)
        #expect(CommandLineInstall.linkToMake(.alreadyLinked("/x"), confirmed: true) == nil)
        #expect(CommandLineInstall.linkToMake(.refuse(reason: "no"), confirmed: true) == nil)
    }

    @Test func eachOutcomeSaysWhatHappened() {
        let at = Self.home + "/.local/bin/afterglow"
        let linked = CommandLineInstall.outcome(.link(at: at, to: Self.cli), writeError: nil, userHome: Self.home)
        #expect(linked.title == CommandLineInstall.installedTitle && linked.message.contains("~/.local/bin/afterglow"))
        let failed = CommandLineInstall.outcome(.link(at: at, to: Self.cli), writeError: "disk full", userHome: Self.home)
        #expect(failed.title == CommandLineInstall.failedTitle && failed.message.contains("disk full"))
        let already = CommandLineInstall.outcome(.alreadyLinked(at), writeError: nil, userHome: Self.home)
        #expect(already.title == CommandLineInstall.alreadyTitle && already.message.contains("already"))
        let refused = CommandLineInstall.outcome(.refuse(reason: "a file is there"), writeError: nil, userHome: Self.home)
        #expect(refused.title == CommandLineInstall.refusedTitle && refused.message == "a file is there")
    }

    @Test func aForeignFileIsRefusedNotReplaced() {
        let plan = AssistantConnect.installPlan(home: Self.home, bundle: Self.bundle) { $0 }
        #expect(CommandLineInstall.linkToMake(plan, confirmed: true) == nil)
        #expect(CommandLineInstall.outcome(plan, writeError: nil, userHome: Self.home).title == CommandLineInstall.refusedTitle)
    }
}
