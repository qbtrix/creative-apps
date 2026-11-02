// AfterGlowJourneyTests+Connect.swift (cli-bundle CB-5, on in CB-6): XJ-CB, Help > Connect an AI Assistant… in
// the launcher. The sheet opens with every control; it shows the bundled command
// (`"…/AfterGlow.app/Contents/Helpers/afterglow" mcp`), Copy puts it on the pasteboard, Install Command-Line Tool…
// asks and Install makes the link in a temp home's `.local/bin` (`-SuiteHomeDir`), and Close shuts the sheet.
// Every click is a mouse click; the menu item is found by title, since SwiftUI carries no id onto a menu item.
import AppKit
import XCTest

extension AfterGlowHelpJourneyTests {
    static let connectControls = ["command", "copyCommand", "config", "copyConfig", "install", "aiAccess", "close"]

    /// Step 1: Connect an AI Assistant… shows the bundled command, copies it, installs the link and closes.
    @MainActor func testConnectAssistant() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("suite-home-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let launcher = SuiteHarness(self).launch(fixture: "firstLaunch", arguments: ["-SuiteHomeDir", home.path])
        let item = Self.openHelp(launcher).menuItems["Connect an AI Assistant…"]
        XCTAssert(item.waitForExistence(timeout: 5), "the Help menu has no Connect an AI Assistant…")
        XCTAssert(item.isEnabled, "Connect an AI Assistant… is disabled in AfterGlow.app")
        item.click()
        let sheet = launcher.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 10), "Help > Connect an AI Assistant… opened no sheet")
        for control in Self.connectControls {
            let id = "suite.help.connect." + control
            XCTAssert(sheet.descendants(matching: .any)[id].waitForExistence(timeout: 5), "the sheet has no \(id)")
        }
        launcher.shot("help-connect")

        // The command names the CLI inside the bundle, quoted.
        let command = sheet.descendants(matching: .any)["suite.help.connect.command"]
        let shown = command.label.isEmpty ? (command.value as? String) ?? "" : command.label
        XCTAssert(shown.hasPrefix("\"") && shown.hasSuffix("/AfterGlow.app/Contents/Helpers/afterglow\" mcp"), "the command is \(shown)")

        // Copy puts exactly that on the pasteboard.
        NSPasteboard.general.clearContents()
        sheet.descendants(matching: .any)["suite.help.connect.copyCommand"].click()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), shown, "Copy copied the wrong text")

        // Install Command-Line Tool…, then Install: the link appears in the temp home, and not before.
        let link = home.appendingPathComponent(".local/bin/afterglow")
        sheet.descendants(matching: .any)["suite.help.connect.install"].click()
        XCTAssertFalse(FileManager.default.fileExists(atPath: link.path), "the link was written before Install")
        launcher.shot("help-install-alert")
        launcher.click("Install", in: .sheet, step: "help-install")
        // OK on the result: the alert that says it's installed comes after the write.
        launcher.click("OK", in: .sheet)
        let target = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)
        XCTAssert(target?.hasSuffix("/AfterGlow.app/Contents/Helpers/afterglow") == true, "no link at \(link.path): \(target ?? "nothing")")

        // Close shuts the sheet.
        sheet.descendants(matching: .any)["suite.help.connect.close"].click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Close left the sheet open")
    }
}
