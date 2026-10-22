// DesignHistoryArea+Kernel.swift: the History panel and the autosave hooks on a Design window
// (design/autosave-history DA-2). DesignHistoryArea keeps whether the panel shows as its own
// state, so the toggle itself never runs the window's body (the narrower canvas still reports
// its new viewport), and publishes that to View > Show History
// as the focused scene value `designHistoryPanel`. Shown, SuiteUI's HistoryPanel sits in a
// GlassPanel beside the editor at the window's trailing edge, so the editor's columns (the
// inspector included) narrow to make room, on the workspace's `historyListing`; a click or
// Return hands the state to `jump`, and a refusal goes to the status line through `onNote`.
// `.autosaveRecovery` reads the workspace through AutosaveHooks: the open file's name, whether it
// is dirty, its `recoveryBytes()` and `restore` for a copy left behind (DesignRecovery+Kernel.swift).
// Copies go to DesignRecoveryStore's folder for this launch (DA-7): `<support>/Design/Recovery/`,
// none for a journey launch or a test host (the ignore-state default) without `-SuiteSupportDir`. `panel` is the panel
// alone, under its "History" title and step count (#3945). DA-3 adds the toolbar's History button: the
// modifier hands its panel state down as the environment value `designHistory`, and
// DesignEditor draws `toolbarAction` from it, selected while the panel shows, off with the
// Model's reason with no file and with `noPanel` outside a window that has the panel.
import DesignModel
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI

/// Whether the focused window's History panel shows, and how to toggle it.
struct DesignHistoryShown {
    var isShown: Bool
    var toggle: @MainActor () -> Void
}

/// A plain key rather than `@Entry`, as DesignMenuKey is, so DesignApp builds without the macro plugin.
private struct DesignHistoryShownKey: FocusedValueKey {
    typealias Value = DesignHistoryShown
}

/// A plain key, as DesignHistoryShownKey is: the panel of the window around a view.
private struct DesignHistoryKey: EnvironmentKey {
    static var defaultValue: DesignHistoryShown? { nil }
}

extension EnvironmentValues {
    /// The History panel of the window this view is in; nil outside a DesignHistoryArea.
    var designHistory: DesignHistoryShown? {
        get { self[DesignHistoryKey.self] }
        set { self[DesignHistoryKey.self] = newValue }
    }
}

extension FocusedValues {
    /// The focused Design window's History panel; nil with no Design window focused.
    var designHistoryPanel: DesignHistoryShown? {
        get { self[DesignHistoryShownKey.self] }
        set { self[DesignHistoryShownKey.self] = newValue }
    }
}

struct DesignHistoryArea: ViewModifier {
    let model: DesignWorkspace
    /// Lands the workspace on a listed state.
    let jump: @MainActor (Int) throws -> Void
    /// Puts a recovered copy's bytes in the window, named for the file it was.
    let restore: @MainActor (Data, String?) throws -> Void
    let onNote: @MainActor (String) -> Void
    /// Whether the panel shows before its first toggle; the tests host it shown.
    var shown = false
    /// The window's id, which names its recovery files.
    @State private var window = UUID().uuidString
    /// Whether the panel was toggled an odd number of times since the window opened.
    @State private var toggled = false

    private var isShown: Bool { shown != toggled }

    func body(content: Content) -> some View {
        let shown = DesignHistoryShown(isShown: isShown) { toggled.toggle() }
        // A sibling, not a trailing safeAreaInset: the editor's NavigationSplitView ignores the
        // inset, so its inspector stayed full width under the panel (#4072).
        return HStack(spacing: 0) {
            content.environment(\.designHistory, shown)
            if isShown { Self.panel(model.historyListing, onJump: jumped) }
        }
        .focusedSceneValue(\.designHistoryPanel, shown)
        .autosaveRecovery(hooks, folder: Self.folder, delay: 2, edits: model.documentSession.currentToken)
    }

    /// Where this launch's windows keep their recovery copies; nil keeps none. The ignore-state default covers
    /// the launch flag and a test host's registered one, so hosted windows never write or offer real copies.
    private static let folder = DesignRecoveryStore.folder(
        arguments: ProcessInfo.processInfo.arguments, home: NSHomeDirectory(),
        ignoringState: UserDefaults.standard.bool(forKey: "ApplePersistenceIgnoreState"))

    private var hooks: AutosaveHooks {
        let model = self.model
        let name = model.documentURL?.lastPathComponent
        let restore = self.restore
        return AutosaveHooks(
            window: window, documentName: { name }, isDirty: { model.isDirty },
            encoder: { Self.encoder(model) },
            restore: { data in try restore(data, name) })
    }

    /// The encode of `model`'s recovery bytes, run off main on this copy; nil with nothing open. A
    /// named function rather than a ternary in the closure, which the type checker gave up on.
    private static func encoder(_ model: DesignWorkspace) -> (@Sendable () throws -> Data)? {
        guard model.isOpen else { return nil }
        return { try model.recoveryBytes() }
    }

    /// A row's jump; a refusal goes to the status line.
    private func jumped(_ index: Int) { Self.jump(index, with: jump, onNote: onNote) }

    /// One jump to `index` through `jump`; a refusal's help goes to `onNote`.
    @MainActor static func jump(
        _ index: Int, with jump: @MainActor (Int) throws -> Void, onNote: @MainActor (String) -> Void
    ) {
        do { try jump(index) } catch { onNote((error as? DesignRefusal)?.help ?? "\(error)") }
    }

    /// Why the History button is off where no window holds a History panel.
    static let noPanel = "Open a Design window to see its history."

    /// The toolbar's History button on `panel`: selected while it shows, a click toggles it.
    @MainActor static func toolbarAction(_ model: DesignWorkspace, _ panel: DesignHistoryShown?) -> ToolbarAction {
        let item = DesignToolbarItem.history
        let help = item.unavailableHelp(in: model) ?? (panel == nil ? noPanel : nil)
        return ToolbarAction(
            item.title(in: model), systemImage: item.systemImage, isSelected: panel?.isShown == true,
            unavailableHelp: help, identifier: item.identifier
        ) { panel?.toggle() }
    }

    /// The panel's accessibility identifier, and its title row's.
    static let panelID = "design.history.panel"
    static let headerID = "design.history.header"

    /// The title row's count: "1 step", "3 steps", "0 steps" before the first edit.
    nonisolated static func stepCount(_ listing: HistoryListing) -> String {
        listing.steps.count == 1 ? "1 step" : "\(listing.steps.count) steps"
    }

    /// The panel on `listing` under its "History" title and step count, at the editor's panel
    /// width, inset from the window's edge (#3945).
    @MainActor static func panel(_ listing: HistoryListing, onJump: @escaping @MainActor (Int) -> Void) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                header(listing)
                HistoryPanel(listing: listing, onJump: onJump)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: SuiteSize.editorPanelWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(panelID)
        .padding(SuiteSpacing.s)
    }

    /// "History" in the headline font, the step count after it in secondary text; one header
    /// element reading "History", valued with the count.
    @MainActor private static func header(_ listing: HistoryListing) -> some View {
        let count = stepCount(listing)
        return HStack(alignment: .firstTextBaseline, spacing: SuiteSpacing.s) {
            Text("History").font(SuiteFont.headline).foregroundStyle(SuiteColor.textPrimary)
            Spacer(minLength: 0)
            Text(count).font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("History")
        .accessibilityValue(count)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(headerID)
    }
}
