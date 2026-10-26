// AIAccessCommands.swift (afterglow-mcp MC-12): Window > AI Access…, and the
// AppKit side of the approval flow on one FakeAIAccess per process: the
// approval sheet begun on the main window, and AIAccessChip as a titlebar
// accessory while a client is connected. MC-10's LiveCommandChannel swaps in
// the live bridge; RenderBudgetAIAccessTests (MC-13) drives it on a test window.
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI

/// The process's AI access state and the windows that show it.
@MainActor @Observable public final class AIAccessCenter {
    public static let shared = AIAccessCenter()

    public private(set) var access: FakeAIAccess?
    private var host: NSWindow?
    private var sheet: NSWindow?
    private var listWindow: NSWindow?
    private var chip: NSTitlebarAccessoryViewController?
    /// The live ask waiting on the sheet's answer.
    private var asking: CheckedContinuation<AIAccessDecision, Never>?

    /// Starts the flow for `app` once; a demo client in `arguments` asks as soon as a main window shows.
    public func start(app: SuiteApp, arguments: [String]) {
        guard access == nil else { return }
        let client = AIAccessPrompt.demoClient(in: arguments)
        access = FakeAIAccess(app: app.displayName, demoClient: client)
        guard let client else { return }
        Task { @MainActor in
            var tries = 0
            while NSApp.mainWindow == nil, tries < 100 { tries += 1; try? await Task.sleep(for: .milliseconds(100)) }
            self.request(client: client)
        }
    }

    /// A client asks to drive `window` (the main window when nil): connects it, or begins the approval sheet.
    public func request(client: String, command: String? = nil, in window: NSWindow? = nil) {
        access?.request(client: client, command: command)
        present(in: window)
    }

    /// Begins the sheet for a pending request on `window` (the main window when nil), and shows or hides the chip.
    private func present(in window: NSWindow?) {
        guard let window = window ?? NSApp.mainWindow ?? NSApp.windows.first(where: \.isVisible) else { return }
        host = window
        if let pending = access?.pending, sheet == nil { beginSheet(pending, on: window) }
        showChip()
    }

    /// A live client's request (LiveCommandChannel's `ask`): begins AIAccessSheet on the main window (else the
    /// first visible one) and returns the person's answer. With no window to hold it, or a sheet already up, it
    /// shows nothing and answers only after the channel's 110 s limit, so the call is refused as "no answer yet"
    /// and nothing is recorded: never a deny the person didn't choose, never an allow they didn't see.
    public func ask(_ request: AIAccessRequest) async -> AIAccessDecision {
        guard sheet == nil, asking == nil, let window = NSApp.mainWindow ?? NSApp.windows.first(where: \.isVisible) else {
            return await withCheckedContinuation { late in
                DispatchQueue.main.asyncAfter(deadline: .now() + 111) { late.resume(returning: .allowOnce) }
            }
        }
        host = window
        beginSheet(request, on: window)
        return await withCheckedContinuation { asking = $0 }
    }

    /// Begins AIAccessSheet for `request` on `window`; its answer goes to `decide`.
    private func beginSheet(_ request: AIAccessRequest, on window: NSWindow) {
        let controller = NSHostingController(rootView: AIAccessSheet(request: request) { [weak self] in self?.decide($0) })
        let panel = NSWindow(contentViewController: controller)
        sheet = panel
        window.beginSheet(panel)
    }

    /// The sheet's answer: records it (or hands it to the live ask waiting on it), closes the sheet, and shows
    /// the chip when the client connected.
    public func decide(_ decision: AIAccessDecision) {
        access?.decide(decision)
        asking?.resume(returning: decision)
        asking = nil
        if let sheet { host?.endSheet(sheet) }
        sheet = nil
        showChip()
    }

    /// The chip's Stop (the demo client's request after it asks on the same window), and Window > AI Access…'s Revoke.
    public func stop() { access?.stop(); present(in: host) }
    public func revoke(_ entry: AIAccessEntry) { access?.revoke(client: entry.client); showChip() }

    /// Opens, or brings forward, the window listing the remembered grants.
    public func showList() {
        if listWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: AIAccessListHost(center: self)))
            window.title = AIAccessPrompt.windowTitle
            listWindow = window
        }
        listWindow?.makeKeyAndOrderFront(nil)
    }

    /// Puts the chip in the host window's title bar while a client is connected, and takes it out after.
    private func showChip() {
        if let chip, let host, let index = host.titlebarAccessoryViewControllers.firstIndex(of: chip) {
            host.removeTitlebarAccessoryViewController(at: index)
        }
        chip = nil
        guard let client = access?.connectedClient, let host else { return }
        let view = NSHostingView(rootView: AIAccessChip(client: client) { [weak self] in self?.stop() })
        view.frame.size = view.fittingSize
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = view
        accessory.layoutAttribute = .right
        host.addTitlebarAccessoryViewController(accessory)
        chip = accessory
    }
}

/// The list window's content, reading the center so a revoke redraws it.
struct AIAccessListHost: View {
    let center: AIAccessCenter

    var body: some View {
        AIAccessList(entries: center.access?.grants.entries ?? []) { center.revoke($0) }
    }
}

/// Window > AI Access…, added by SuiteCommands, so every window offers the list.
public struct AIAccessCommands: Commands {
    @MainActor public init(app: SuiteApp) {
        AIAccessCenter.shared.start(app: app, arguments: ProcessInfo.processInfo.arguments)
    }

    public var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button(AIAccessPrompt.menuTitle, systemImage: AIAccessPrompt.menuSymbol) { AIAccessCenter.shared.showList() }
        }
    }
}
