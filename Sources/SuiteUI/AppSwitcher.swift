// AppSwitcher.swift: the suite's app switcher, one centered row of monochrome
// line icons in a SuiteWindow's toolbar (Home, Flare, Design, Photo, Library,
// Halo), no labels and no bar behind it (docs/blueprints/suiteui.md section 6).
// The current app's item sits in a capsule of SuiteUI glass (`suiteGlass`, the
// row's one glass shape) with its icon in textPrimary; the others are
// textSecondary. Item centers sit `spacing` apart, one of `spacingSteps`
// (80, 64, 48, 40: from `switcherSpacing` down by SuiteSpacing.l to
// `switcherSpacingMinimum`), or the last step, `compactSpacing` (toolButton,
// 32), when none of them fits. A toolbar item is never offered less than its
// ideal width, so ViewThatFits there would always keep 80 and push the
// window's actions into the overflow (run 38897404951); SuiteWindow instead
// passes `toolbarSpacing(windowWidth:…)`, the widest step whose row leaves the
// toolbar's leading and trailing buttons their room, so in a crowded toolbar
// (Design's eight commands) the switcher gives way, not the actions. The
// capsule narrows with the step (`capsuleWidth(spacing:)`, and at the compact
// step `capsuleHeight(spacing:)` too) so it never reaches a neighbour's icon. An item
// that can't switch yet is disabled and its tooltip says why after the app's
// name and shortcut ("Design (⌃⌘2)", then the reason on a new line). The row is
// the container `suite.switcher`; each item is `suite.switcher.<id>` and lists
// itself in `suite.controls`. AppSwitcherState is what a SuiteWindow shows:
// the environment's `suiteSwitcher`, or `placeholder(processName:)` until the
// switching feature wires it, with every item disabled and the current one
// picked from the running executable's name. Tested in AppSwitcherTests and
// SuiteAppSwitcherSnapshots.
import SwiftUI

public struct AppSwitcherItem: Identifiable, Sendable {
    /// "home", "flare", …; the accessibility identifier is "suite.switcher.<id>".
    public let id: String
    /// The app's name: the accessibility label and the tooltip's first words.
    public let title: String
    /// A monochrome line SF Symbol.
    public let systemImage: String
    /// The key equivalent shown in the tooltip ("⌃⌘2").
    public let shortcut: String
    /// Why the item can't switch yet; non-nil shows it disabled with this reason.
    public let unavailableHelp: String?

    public init(id: String, title: String, systemImage: String, shortcut: String, unavailableHelp: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.unavailableHelp = unavailableHelp
    }

    /// The tooltip: "Design (⌃⌘2)", then the reason on a new line when unavailable.
    public var help: String {
        let name = "\(title) (\(shortcut))"
        guard let unavailableHelp else { return name }
        return "\(name)\n\(unavailableHelp)"
    }
}

public struct AppSwitcher: View {
    private let items: [AppSwitcherItem]
    private let current: AppSwitcherItem.ID?
    private let spacing: CGFloat
    private let onSelect: @MainActor (AppSwitcherItem.ID) -> Void

    /// `spacing` is the distance between item centers, `switcherSpacing` unless
    /// the toolbar needs a narrower step (`toolbarSpacing(windowWidth:…)`).
    public init(
        items: [AppSwitcherItem], current: AppSwitcherItem.ID?, spacing: CGFloat = SuiteSize.switcherSpacing,
        onSelect: @escaping @MainActor (AppSwitcherItem.ID) -> Void
    ) {
        self.items = items
        self.current = current
        self.spacing = spacing
        self.onSelect = onSelect
    }

    /// The distances between item centers the row may use, widest first:
    /// from `switcherSpacing` down by SuiteSpacing.l, then `switcherSpacingMinimum`.
    nonisolated public static let spacingSteps: [CGFloat] =
        Array(stride(from: SuiteSize.switcherSpacing, to: SuiteSize.switcherSpacingMinimum, by: -SuiteSpacing.l))
        + [SuiteSize.switcherSpacingMinimum]

    /// The last step, below `switcherSpacingMinimum`: a tool button's width,
    /// so each item stays a full-size click target. The row takes it when no
    /// step of `spacingSteps` fits (Design's eight commands at 1000 to 1024 pt);
    /// it is the narrowest the row gets.
    nonisolated public static let compactSpacing: CGFloat = SuiteSize.toolButton

    /// The toolbar width one button takes: its share of its glass group
    /// (measured 36 to 37.5 pt in runs 38897404951 and 38938835086).
    nonisolated public static let toolbarButtonRoom: CGFloat = SuiteSize.toolButton + SuiteSpacing.xs
    /// From the leading buttons' end to where the row starts: the window title's
    /// slot, which the toolbar keeps about 155 pt wide whatever the title
    /// ("Flare", "Untitled Project", "journey.design"), and its gaps. Measured,
    /// the row starts at 423 to 424 pt after one leading button and at 538 pt
    /// after Design's four; this model says 432 and 540.
    nonisolated public static let titleRoom: CGFloat = 5 * toolbarButtonRoom + SuiteSpacing.l
    /// Past the trailing buttons: the window edge's margin (about 10 pt) and the
    /// least gap the toolbar keeps before its trailing group. A row 12 pt
    /// (Halo, 1000 pt at 80) or about 16 pt (Design, 1024 pt at 40) from that
    /// group pushed buttons into the overflow; 36 pt (Halo, 1024 pt at 80) kept them.
    nonisolated public static let trailingClearance: CGFloat = 2 * SuiteSpacing.xl

    /// Where the row's leading edge can be at the earliest: the sidebar column,
    /// `leadingButtons` and the title's slot.
    nonisolated public static func toolbarLeading(leadingButtons: Int) -> CGFloat {
        SuiteSize.sidebarWidth.ideal + CGFloat(max(leadingButtons, 0)) * toolbarButtonRoom + titleRoom
    }

    /// The room `trailingButtons` take at the window's trailing end, with their clearance.
    nonisolated public static func toolbarTrailing(trailingButtons: Int) -> CGFloat {
        CGFloat(max(trailingButtons, 0)) * toolbarButtonRoom + trailingClearance
    }

    /// Where the row of `itemCount` items at `spacing` ends in a window
    /// `windowWidth` wide: the toolbar centers it in the window unless that
    /// would overlap the leading end, and then starts it at the leading end
    /// (every journey shot so far shows the second).
    nonisolated public static func rowEnd(
        windowWidth: CGFloat, spacing: CGFloat, itemCount: Int, leadingButtons: Int
    ) -> CGFloat {
        let row = spacing * CGFloat(max(itemCount, 0))
        return max(windowWidth / 2 - row / 2, toolbarLeading(leadingButtons: leadingButtons)) + row
    }

    /// The widest of `spacingSteps` whose row of `itemCount` items ends
    /// before the trailing buttons' room (`rowEnd` ≤ windowWidth −
    /// `toolbarTrailing`), else `compactSpacing`: the switcher gives way
    /// before any toolbar action goes into the overflow. Before the window is
    /// measured (width 0) nothing fits, so it is `compactSpacing` too.
    nonisolated public static func toolbarSpacing(
        windowWidth: CGFloat, itemCount: Int, leadingButtons: Int, trailingButtons: Int
    ) -> CGFloat {
        let limit = windowWidth - toolbarTrailing(trailingButtons: trailingButtons)
        return spacingSteps.first {
            rowEnd(windowWidth: windowWidth, spacing: $0, itemCount: itemCount, leadingButtons: leadingButtons)
                <= limit
        } ?? compactSpacing
    }

    /// The current item's capsule height at `spacing`: `switcherCapsule.height`,
    /// or a tool button's height at the compact step, where the item is that wide.
    nonisolated public static func capsuleHeight(spacing: CGFloat) -> CGFloat {
        spacing < SuiteSize.switcherSpacingMinimum ? SuiteSize.toolButton : SuiteSize.switcherCapsule.height
    }

    /// The current item's capsule width at `spacing`: `switcherCapsule.width`,
    /// narrowed so each end stays SuiteSpacing.xs clear of a neighbour's icon
    /// (90 at 80 and 64, 66 at 48, 50 at 40, 34 at 32), and never under the
    /// capsule's height, so it stays a capsule.
    nonisolated public static func capsuleWidth(spacing: CGFloat) -> CGFloat {
        let clear = 2 * (spacing - SuiteSize.switcherIcon / 2 - SuiteSpacing.xs)
        return max(capsuleHeight(spacing: spacing), min(SuiteSize.switcherCapsule.width, clear))
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isCurrent = item.id == current
                Button {
                    onSelect(item.id)
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: SuiteSize.switcherIcon))
                        .foregroundStyle(isCurrent ? SuiteColor.textPrimary : SuiteColor.textSecondary)
                        .frame(width: spacing, height: Self.capsuleHeight(spacing: spacing))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background {
                    if isCurrent {
                        Color.clear
                            .frame(
                                width: Self.capsuleWidth(spacing: spacing), height: Self.capsuleHeight(spacing: spacing))
                            .suiteGlass(in: Capsule())
                    }
                }
                .disabled(item.unavailableHelp != nil)
                // After .disabled, so the tooltip still shows on a disabled item.
                .help(item.help)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
                .suiteControl(
                    id: "suite.switcher.\(item.id)", enabled: item.unavailableHelp == nil, reason: item.unavailableHelp)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.switcher")
    }
}

/// What a SuiteWindow's switcher shows: its items, the current one and what a
/// click on an enabled item does.
public struct AppSwitcherState: Sendable {
    public var items: [AppSwitcherItem]
    public var current: AppSwitcherItem.ID?
    public var onSelect: @MainActor @Sendable (AppSwitcherItem.ID) -> Void

    public init(
        items: [AppSwitcherItem], current: AppSwitcherItem.ID?,
        onSelect: @escaping @MainActor @Sendable (AppSwitcherItem.ID) -> Void
    ) {
        self.items = items
        self.current = current
        self.onSelect = onSelect
    }
}

extension AppSwitcherState {
    /// Why the placeholder's items can't switch yet.
    public static let notConnected = "Not connected yet (switching)."

    /// Home plus the five apps, every item disabled "Not connected yet
    /// (switching)."; the current item is the one whose app runs this process
    /// (the executable "DesignApp" → "design"; anything else → none).
    public static func placeholder(processName: String) -> AppSwitcherState {
        let apps: [(id: String, title: String, systemImage: String)] = [
            ("home", "Home", "house"),
            ("flare", "Flare", "flame"),
            ("design", "Design", "pencil.and.outline"),
            ("photo", "Photo", "camera.aperture"),
            ("library", "Library", "photo.on.rectangle"),
            ("halo", "Halo", "film"),
        ]
        let items = apps.enumerated().map { index, app in
            AppSwitcherItem(
                id: app.id, title: app.title, systemImage: app.systemImage, shortcut: "⌃⌘\(index)",
                unavailableHelp: notConnected)
        }
        // Home is not an app with an executable of its own.
        let current = items.first { $0.id != "home" && "\($0.title)App" == processName }?.id
        return AppSwitcherState(items: items, current: current, onSelect: { _ in })
    }
}

extension EnvironmentValues {
    /// The switcher a SuiteWindow shows; nil shows the placeholder. A plain key
    /// rather than `@Entry`, as in Glass.swift.
    public var suiteSwitcher: AppSwitcherState? {
        get { self[SuiteSwitcherKey.self] }
        set { self[SuiteSwitcherKey.self] = newValue }
    }
}

private struct SuiteSwitcherKey: EnvironmentKey {
    static let defaultValue: AppSwitcherState? = nil
}
