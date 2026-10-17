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
// passes `toolbarFit(windowWidth:…)`, worked out from each toolbar item's real
// width (`toolbarRoom`: a tool button, or wider when its title shows), the
// window's own controls and a safety margin. When even the compact row would
// crowd the actions (the editor gallery at 900 pt, Flare at 1000 pt, run
// 38981651490), the row gives way further and shows the current app's item
// alone (`AppSwitcherState.shownItems`): `suite.switcher` stays, with the
// current app selected, and no action goes into the overflow. The capsule narrows with the step (`capsuleWidth(spacing:)`, and at the compact
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

/// A toolbar item the switcher's row leaves room for: its title, and whether
/// the toolbar draws that title beside the icon.
public struct SwitcherToolbarItem: Equatable, Sendable {
    public let title: String
    public let showsTitle: Bool

    public init(_ title: String, showsTitle: Bool = false) {
        self.title = title
        self.showsTitle = showsTitle
    }
}

/// How the switcher's row fits its toolbar: the distance between item centers,
/// and whether every item shows or only the current app's.
public struct SwitcherToolbarFit: Equatable, Sendable {
    public let spacing: CGFloat
    public let showsEveryItem: Bool

    public init(spacing: CGFloat, showsEveryItem: Bool) {
        self.spacing = spacing
        self.showsEveryItem = showsEveryItem
    }
}

public struct AppSwitcher: View {
    private let items: [AppSwitcherItem]
    private let current: AppSwitcherItem.ID?
    private let spacing: CGFloat
    private let onSelect: @MainActor (AppSwitcherItem.ID) -> Void

    /// `spacing` is the distance between item centers, `switcherSpacing` unless
    /// the toolbar needs a narrower step (`toolbarFit(windowWidth:…)`).
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
    /// step of `spacingSteps` fits (Design's eight commands at 1024 pt); it is
    /// the narrowest the row gets, and below it the current item shows alone.
    nonisolated public static let compactSpacing: CGFloat = SuiteSize.toolButton

    /// The toolbar width one icon-only button takes: its share of its glass
    /// group (measured 36 to 37.5 pt in runs 38897404951 and 38938835086).
    nonisolated public static let toolbarButtonRoom: CGFloat = SuiteSize.toolButton + SuiteSpacing.xs
    /// What one character of a shown title adds to its button: an upper bound
    /// for the toolbar's 13 pt system font, so a labelled item is never counted short.
    nonisolated public static let titleCharacterRoom: CGFloat = SuiteSpacing.s - 1
    /// The window's own controls (close, minimize, zoom) at the leading edge,
    /// about 78 pt; the sidebar column is wider, so they only bound the
    /// leading end when that column is narrower than them.
    nonisolated public static let windowControlsRoom: CGFloat = 2 * SuiteSpacing.xl + SuiteSpacing.xxl
    /// From the leading buttons' end to where the row starts: the window title's
    /// slot, which the toolbar keeps about 155 pt wide whatever the title
    /// ("Flare", "Untitled Project", "journey.design"), and its gaps. Measured,
    /// the row starts at 423 to 424 pt after one leading button, at 475 pt
    /// after three (run 38981651490) and at 538 pt after Design's four; this
    /// model says 432, 504 and 540.
    nonisolated public static let titleRoom: CGFloat = 5 * toolbarButtonRoom + SuiteSpacing.l
    /// Past the trailing buttons: the window edge's margin (about 10 pt) and the
    /// least gap the toolbar keeps before its trailing group. A row 12 pt
    /// (Halo, 1000 pt at 80) or about 16 pt (Design, 1024 pt at 40) from that
    /// group pushed buttons into the overflow; 36 pt (Halo, 1024 pt at 80) kept them.
    nonisolated public static let trailingClearance: CGFloat = 2 * SuiteSpacing.xl
    /// Kept free on top of every measured room, so a rounding or a title a
    /// little wider than measured never tips a button into the overflow.
    nonisolated public static let safetyMargin: CGFloat = SuiteSpacing.s

    /// The toolbar width `item` takes: a tool button's room, plus its title
    /// when the toolbar draws it ("New Sample Animation" as a labelled button
    /// takes 180 pt, not 36).
    nonisolated public static func toolbarRoom(_ item: SwitcherToolbarItem) -> CGFloat {
        guard item.showsTitle else { return toolbarButtonRoom }
        return toolbarButtonRoom + CGFloat(item.title.count) * titleCharacterRoom + SuiteSpacing.xs
    }

    /// Where the row's leading edge can be at the earliest: the sidebar column
    /// (or the window's controls, if wider), the window's sidebar toggle,
    /// `documentActions` and the title's slot.
    nonisolated public static func toolbarLeading(documentActions: [SwitcherToolbarItem]) -> CGFloat {
        max(SuiteSize.sidebarWidth.ideal, windowControlsRoom) + toolbarButtonRoom
            + documentActions.reduce(0) { $0 + toolbarRoom($1) } + titleRoom
    }

    /// The room the trailing end takes: `actions`, the window's inspector
    /// toggle, their clearance and the safety margin.
    nonisolated public static func toolbarTrailing(actions: [SwitcherToolbarItem]) -> CGFloat {
        actions.reduce(0) { $0 + toolbarRoom($1) } + toolbarButtonRoom + trailingClearance + safetyMargin
    }

    /// Where the row of `itemCount` items at `spacing` ends in a window
    /// `windowWidth` wide: the toolbar centers it in the window unless that
    /// would overlap the leading end (`leading`), and then starts it there
    /// (every journey shot so far shows the second).
    nonisolated public static func rowEnd(
        windowWidth: CGFloat, spacing: CGFloat, itemCount: Int, leading: CGFloat
    ) -> CGFloat {
        let row = spacing * CGFloat(max(itemCount, 0))
        return max(windowWidth / 2 - row / 2, leading) + row
    }

    /// How the row fits a toolbar: the widest of `spacingSteps` whose row of
    /// `itemCount` items ends before the trailing room (`rowEnd` ≤ windowWidth
    /// − `toolbarTrailing`); else `compactSpacing` with every item if that
    /// fits; else the current item alone at `compactSpacing`, so the switcher
    /// gives way and no toolbar action goes into the overflow (the editor
    /// gallery at 900 pt, run 38981651490). Before the window is measured
    /// (width 0) nothing fits, so it is the current item alone too.
    nonisolated public static func toolbarFit(
        windowWidth: CGFloat, itemCount: Int, documentActions: [SwitcherToolbarItem], actions: [SwitcherToolbarItem]
    ) -> SwitcherToolbarFit {
        let leading = toolbarLeading(documentActions: documentActions)
        let limit = windowWidth - toolbarTrailing(actions: actions)
        let fits = { (spacing: CGFloat) in
            rowEnd(windowWidth: windowWidth, spacing: spacing, itemCount: itemCount, leading: leading) <= limit
        }
        if let step = (spacingSteps + [compactSpacing]).first(where: fits) {
            return SwitcherToolbarFit(spacing: step, showsEveryItem: true)
        }
        return SwitcherToolbarFit(spacing: compactSpacing, showsEveryItem: false)
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
    /// The items the row shows: every one, or, when the toolbar has no room
    /// for them (`SwitcherToolbarFit.showsEveryItem` false), the current
    /// app's alone, or the first item when none is current.
    public func shownItems(everyItem: Bool) -> [AppSwitcherItem] {
        guard !everyItem else { return items }
        if let shown = items.first(where: { $0.id == current }) { return [shown] }
        return Array(items.prefix(1))
    }

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
