// InstallCommandLineTool.swift (cli-bundle CB-6): Install Command-Line Tool… on the Connect an AI Assistant sheet.
// It asks first, an alert as a sheet on the connect window naming `~/.local/bin/afterglow` with Install and Cancel,
// and writes nothing before Install. Install reads what is at the link now, follows AssistantConnect.installPlan
// (a file or another link there is never replaced) and makes the folder and the symlink only for a `.link` plan;
// a second alert says what happened. Every word and decision is CommandLineInstall's; this file is the glue. The
// home is `-SuiteHomeDir`'s value when a journey passes one. An NSAlert, since SwiftUI drops alert buttons' ids.
import AppKit
import SuiteModel

@MainActor enum InstallCommandLineTool {
    /// Asks, then installs `bundle`'s afterglow into the home `arguments` name (the person's home by default).
    static func run(
        bundle: String, on window: NSWindow?, arguments: [String] = ProcessInfo.processInfo.arguments,
        userHome: String = NSHomeDirectory()
    ) async {
        if let window, window.attachedSheet != nil { return }
        let home = CommandLineInstall.home(arguments: arguments, fallback: userHome)
        let answer = await show(CommandLineInstall.prompt(home: home, userHome: userHome), on: window)
        let plan = AssistantConnect.installPlan(home: home, bundle: bundle, existing: existing)
        guard answer == .alertFirstButtonReturn else { return }
        let writeError = CommandLineInstall.linkToMake(plan, confirmed: true).flatMap(make)
        _ = await show(CommandLineInstall.outcome(plan, writeError: writeError, userHome: userHome), on: window)
    }

    /// The link's target, the path itself for any other file, or nil when nothing is there.
    static func existing(_ path: String) -> String? {
        if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: path) { return target }
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// Makes the link's folder if needed, then the link; why it failed, or nil when it landed.
    static func make(_ link: CommandLineInstall.Link) -> String? {
        let folder = URL(fileURLWithPath: link.at).deletingLastPathComponent().path
        do {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createSymbolicLink(atPath: link.at, withDestinationPath: link.to)
            return nil
        } catch {
            return "Couldn't make the link at \(link.at): \(error.localizedDescription)"
        }
    }

    /// `message` as an alert, a sheet on `window` (modal when nil); the button pressed.
    static func show(_ message: CommandLineInstall.Message, on window: NSWindow?) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = message.title
        alert.informativeText = message.message
        for title in message.buttons {
            alert.addButton(withTitle: title).setAccessibilityIdentifier("suite.help.connect.install." + title.lowercased())
        }
        guard let window else { return alert.runModal() }
        return await alert.beginSheetModal(for: window)
    }
}
