// SuiteSheet.swift: the one frame every app sheet is drawn in (#3964): a
// headline title, the host's content, an optional secondary message line, and
// a trailing row of Cancel (Escape) and one default action (Return). The
// default action is the host's MenuCommand, usually built from its command
// catalog, so the spec's availability still decides it; a non-nil `reason`
// from the host also disables it and becomes its help, so a disabled default
// always says why. Cancel and the action carry the ids the host passes and
// list in the window's `suite.controls`; the action's role is "primary".
// Width is the host's (sheets differ); padding and spacing are the suite's.
import SwiftUI

public struct SuiteSheet<Content: View>: View {
    let title: String, message: String?, messageID: String?, width: CGFloat
    let cancelID: String, onCancel: @MainActor () -> Void
    let action: MenuCommand, actionID: String
    let content: Content

    public init(
        _ title: String, message: String? = nil, messageID: String? = nil, width: CGFloat = SuiteSize.contentMinimum.width,
        cancelID: String, onCancel: @escaping @MainActor () -> Void,
        action: MenuCommand, actionID: String, reason: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        (self.title, self.message, self.messageID, self.width) = (title, message, messageID, width)
        (self.cancelID, self.onCancel) = (cancelID, onCancel)
        (self.action, self.actionID) = (Self.defaultCommand(action, reason: reason), actionID)
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text(title).font(SuiteFont.headline)
            content
            if let message {
                Text(message).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(messageID ?? "")
            }
            HStack(spacing: SuiteSpacing.s) {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .suiteControl(id: cancelID, enabled: true, reason: nil)
                action
                    .suiteControl(id: actionID, enabled: action.isEnabled, reason: action.isEnabled ? nil : action.help, role: "primary")
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: width)
    }

    /// The host's command on Return; off with `reason` as its help when the host gives one.
    // view-static: main-actor
    static func defaultCommand(_ action: MenuCommand, reason: String?) -> MenuCommand {
        MenuCommand(action.title, systemImage: action.systemImage, shortcut: .defaultAction, help: reason ?? action.help,
                    isEnabled: action.isEnabled && reason == nil, role: action.role, perform: action.perform)
    }
}
