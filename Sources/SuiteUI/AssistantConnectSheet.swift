// AssistantConnectSheet.swift (cli-bundle CB-5): Help > Connect an AI Assistant…'s sheet over an
// AssistantConnectPanel. The command an MCP client runs and the JSON block for clients that take one, each
// read-only with its own Copy, then Install Command-Line Tool…, Open AI Access and Close. The panel decides
// the text and which buttons act; a button that can't act is disabled and says why (no dead controls). The
// sheet copies nothing itself: Copy hands its text to the host. Every control carries
// `suite.help.connect.<control>`.
import SuiteModel
import SwiftUI

/// The Connect an AI Assistant sheet over `panel`.
public struct AssistantConnectSheet: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    /// The controls, each with its `identifier(_:)`.
    nonisolated static let controls = ["command", "copyCommand", "config", "copyConfig", "install", "aiAccess", "close"]
    nonisolated static func identifier(_ control: String) -> String { "suite.help.connect." + control }

    private let panel: AssistantConnectPanel
    private let onCopy: @MainActor (String) -> Void
    private let onInstall: (@MainActor () -> Void)?
    private let onOpenAIAccess: @MainActor () -> Void
    private let onClose: @MainActor () -> Void

    /// A nil `onInstall`, or a panel that says install can't run, shows Install disabled with the panel's reason.
    public init(
        panel: AssistantConnectPanel, onCopy: @escaping @MainActor (String) -> Void, onInstall: (@MainActor () -> Void)? = nil,
        onOpenAIAccess: @escaping @MainActor () -> Void, onClose: @escaping @MainActor () -> Void
    ) {
        self.panel = panel
        (self.onCopy, self.onInstall, self.onOpenAIAccess, self.onClose) = (onCopy, onInstall, onOpenAIAccess, onClose)
    }

    public var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                Text("Connect an AI Assistant").font(SuiteFont.title)
                Text("Give your MCP client this command, or paste the JSON block into a client that takes one.")
                    .font(SuiteFont.body).foregroundStyle(SuiteColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            block("Command", text: panel.shownCommand, id: "command",
                  copy: panel.command, why: panel.copyCommandUnavailable, copyID: "copyCommand")
            block("JSON config", text: panel.shownConfig, id: "config",
                  copy: panel.configJSON, why: panel.copyConfigUnavailable, copyID: "copyConfig")
            HStack(spacing: SuiteSpacing.s) {
                Button("Close", role: .cancel) { onClose() }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier(Self.identifier("close"))
                Spacer()
                Button("Open AI Access") { onOpenAIAccess() }
                    .help("Lists the assistants allowed to drive the suite's windows.")
                    .accessibilityIdentifier(Self.identifier("aiAccess"))
                Button("Install Command-Line Tool…") { onInstall?() }
                    .disabled(installWhy != nil).help(installWhy ?? "Links afterglow into ~/.local/bin, after you confirm.")
                    .accessibilityIdentifier(Self.identifier("install"))
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentIdealWidth)
    }

    /// Why Install is disabled: the panel's reason, or that the host passed no install.
    private var installWhy: String? { panel.installUnavailable ?? (onInstall == nil ? AssistantConnectPanel.installNeedsBundle : nil) }

    /// A titled read-only box of `text` with a Copy that hands `copy` to the host, or is disabled saying `why`.
    private func block(_ title: String, text: String, id: String, copy: String, why: String?, copyID: String) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            HStack(spacing: SuiteSpacing.s) {
                Text(title).font(SuiteFont.headline)
                Spacer()
                Button("Copy") { onCopy(copy) }
                    .disabled(why != nil).help(why ?? "Copies it to the clipboard.")
                    .accessibilityIdentifier(Self.identifier(copyID))
            }
            Text(text).font(SuiteFont.timecode).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(SuiteSpacing.s)
                .background(SuiteColor.card, in: RoundedRectangle(cornerRadius: SuiteRadius.control))
                .accessibilityIdentifier(Self.identifier(id))
        }
    }
}
