// AppSwitcherTests.swift: the app switcher's items and placeholder
// (AppSwitcher.swift). The placeholder lists Home and the five apps in order
// with their shortcuts, every item disabled with its reason; the current item
// follows the running executable; the tooltip names the app and its shortcut
// and then the reason; the identifiers are unique; the spacing steps run from
// the ideal down to the minimum, then the compact step; a labelled toolbar item
// counts its title's width; the room model matches the toolbar positions
// measured in runs 38897404951, 38938835086 and 38981651490; the toolbar fit
// leaves Flare's, Halo's, Library's, Design's and the editor gallery's toolbar
// buttons their room at every width, takes the compact step when no step fits,
// and shows the current item alone when even that doesn't (the editor gallery
// at 900 pt, Flare at 1000 pt); the capsule never reaches a neighbour's icon.
// macOS only.
import SuiteUI
import SwiftUI
import Testing

@Suite struct AppSwitcherTests {
    @Test func thePlaceholderListsHomeAndTheFiveAppsInOrder() {
        let items = AppSwitcherState.placeholder(processName: "xctest").items
        #expect(items.map(\.id) == ["home", "flare", "design", "photo", "library", "halo"])
        #expect(items.map(\.title) == ["Home", "Flare", "Design", "Photo", "Library", "Halo"])
        #expect(items.map(\.shortcut) == ["⌃⌘0", "⌃⌘1", "⌃⌘2", "⌃⌘3", "⌃⌘4", "⌃⌘5"])
        #expect(items.allSatisfy { !$0.systemImage.isEmpty })
    }

    @Test func everyPlaceholderItemIsDisabledAndSaysWhy() {
        for item in AppSwitcherState.placeholder(processName: "DesignApp").items {
            #expect(item.unavailableHelp == "Not connected yet (switching).", "\(item.id)")
        }
    }

    @Test func theCurrentItemIsTheRunningApp() {
        #expect(AppSwitcherState.placeholder(processName: "DesignApp").current == "design")
        #expect(AppSwitcherState.placeholder(processName: "LibraryApp").current == "library")
        #expect(AppSwitcherState.placeholder(processName: "xctest").current == nil)
        #expect(AppSwitcherState.placeholder(processName: "").current == nil)
        #expect(AppSwitcherState.placeholder(processName: "HomeApp").current == nil)
    }

    @Test func theTooltipNamesTheAppAndShortcutThenTheReason() {
        let ready = AppSwitcherItem(id: "design", title: "Design", systemImage: "pencil.and.outline", shortcut: "⌃⌘2")
        #expect(ready.help == "Design (⌃⌘2)")
        let waiting = AppSwitcherItem(
            id: "design", title: "Design", systemImage: "pencil.and.outline", shortcut: "⌃⌘2",
            unavailableHelp: "Not connected yet (switching).")
        #expect(waiting.help == "Design (⌃⌘2)\nNot connected yet (switching).")
    }

    @Test func theIdentifiersAreUnique() {
        let ids = AppSwitcherState.placeholder(processName: "xctest").items.map { "suite.switcher.\($0.id)" }
        #expect(ids.count == 6)
        #expect(Set(ids).count == ids.count)
    }

    @Test func theSpacingStepsDownFromTheIdealToTheMinimum() {
        #expect(AppSwitcher.spacingSteps == [80, 64, 48, 40])
        #expect(AppSwitcher.spacingSteps.first == SuiteSize.switcherSpacing)
        #expect(AppSwitcher.spacingSteps.last == SuiteSize.switcherSpacingMinimum)
        #expect(SuiteSize.switcherCapsule == CGSize(width: 90, height: 48))
        #expect(SuiteSize.switcherIcon == 22)
    }

    @Test func theCompactStepIsAToolButtonBelowTheMinimum() {
        #expect(AppSwitcher.compactSpacing == SuiteSize.toolButton)
        #expect(AppSwitcher.compactSpacing < SuiteSize.switcherSpacingMinimum)
        #expect(!AppSwitcher.spacingSteps.contains(AppSwitcher.compactSpacing))
    }

    /// Each toolbar the switcher shares, as SuiteWindow passes it (titles, drawn icon only):
    /// (document actions, actions). SuiteWindow's sidebar and inspector toggles come on top.
    static let toolbars: [String: (docs: [String], actions: [String])] = [
        "flare": ([], ["New", "Open", "Save", "Undo", "Redo", "Auto-key", "Animate…", "Export…"]),
        "halo": ([], ["New Composition…"]),
        "library": ([], []),
        "design": (["New", "Open", "Save"], ["Undo", "Redo", "Zoom Out", "Fit", "Zoom In"]),
        "editor": (["New", "Open"], ["Save", "Undo", "Redo", "Zoom Out", "Fit", "Zoom In"]),
    ]

    private func fit(_ name: String, _ width: CGFloat) -> SwitcherToolbarFit {
        let toolbar = Self.toolbars[name] ?? (docs: [], actions: [])
        return AppSwitcher.toolbarFit(
            windowWidth: width, itemCount: 6, documentActions: toolbar.docs.map { SwitcherToolbarItem($0) },
            actions: toolbar.actions.map { SwitcherToolbarItem($0) })
    }

    @Test func aLabelledItemTakesItsTitlesWidth() {
        let button = SuiteSize.toolButton + SuiteSpacing.xs
        #expect(Self.same(AppSwitcher.toolbarRoom(SwitcherToolbarItem("Fit")), button))
        #expect(Self.same(AppSwitcher.toolbarRoom(SwitcherToolbarItem("New Sample Animation")), 36))
        // 20 characters at 7 pt beside the icon.
        #expect(Self.same(AppSwitcher.toolbarRoom(SwitcherToolbarItem("New Sample Animation", showsTitle: true)), 180))
        #expect(Self.same(AppSwitcher.toolbarRoom(SwitcherToolbarItem("", showsTitle: true)), 40))
        // Flare at 1024 pt keeps the compact row with icon-only buttons, but one labelled button gives it away.
        #expect(fit("flare", 1024) == SwitcherToolbarFit(spacing: 32, showsEveryItem: true))
        let labelled = (Self.toolbars["flare"]?.actions ?? []).map { SwitcherToolbarItem($0) }
            + [SwitcherToolbarItem("New Sample Animation", showsTitle: true)]
        #expect(
            AppSwitcher.toolbarFit(windowWidth: 1024, itemCount: 6, documentActions: [], actions: labelled)
                == SwitcherToolbarFit(spacing: 32, showsEveryItem: false))
    }

    @Test func theRoomModelMatchesTheMeasuredToolbars() {
        // The row started at 423 to 424 pt after one leading button (Flare, Halo, Library), at 475 pt
        // after the editor gallery's three (run 38981651490) and at 538 pt after Design's four.
        let items = { (titles: [String]) in titles.map { SwitcherToolbarItem($0) } }
        #expect(Self.same(AppSwitcher.toolbarLeading(documentActions: []), 432))
        #expect(Self.same(AppSwitcher.toolbarLeading(documentActions: items(["New", "Open"])), 504))
        #expect(Self.same(AppSwitcher.toolbarLeading(documentActions: items(["New", "Open", "Save"])), 540))
        // The window's own controls sit inside the sidebar column; the safety margin is on top.
        #expect(AppSwitcher.windowControlsRoom < SuiteSize.sidebarWidth.ideal)
        // The inspector toggle's button, the clearance and the safety margin: 36 + 48 + 8 = 92 pt.
        let trailing = SuiteSize.toolButton + SuiteSpacing.xs + 2 * SuiteSpacing.xl + SuiteSpacing.s
        #expect(Self.same(AppSwitcher.toolbarTrailing(actions: []), trailing))
        #expect(Self.same(trailing, 92))
        // Overflowed: Halo at 1000 pt with 80 (run 38897404951), Design at 1024 pt with 40 (run 38938835086),
        // and the editor gallery at 900 pt with the compact row (run 38981651490: Fit, Zoom In and the
        // inspector toggle went into the overflow).
        #expect(!fits("halo", width: 1000, spacing: 80))
        #expect(!fits("design", width: 1024, spacing: 40))
        #expect(!fits("editor", width: 900, spacing: 32))
        // Kept every button: Halo at 880 pt with 48, Library at 900 pt with 40.
        #expect(fits("halo", width: 880, spacing: 48))
        #expect(fits("library", width: 900, spacing: 40))
    }

    @Test func theToolbarFitGivesEachAppsWindowItsStep() {
        let every = { (spacing: CGFloat) in SwitcherToolbarFit(spacing: spacing, showsEveryItem: true) }
        let alone = SwitcherToolbarFit(spacing: 32, showsEveryItem: false)
        // The editor gallery: at 900 pt (run 38981651490) the current item alone; at 1024 pt the compact row.
        #expect(fit("editor", 900) == alone)
        #expect(fit("editor", 1024) == every(32))
        // Flare's eight actions: the current item alone at 1000 pt, the compact row at 1024 pt.
        #expect(fit("flare", 1000) == alone)
        #expect(fit("flare", 1024) == every(32))
        // Design's toolbar: the same.
        #expect(fit("design", 1000) == alone)
        #expect(fit("design", 1024) == every(32))
        // Halo at its launch width, its layout sizes and the minimum.
        #expect(fit("halo", 1000) == every(64))
        #expect(fit("halo", 1024) == every(64))
        #expect(fit("halo", 880) == every(48))
        // Library: the inspector toggle only.
        #expect(fit("library", 1000) == every(64))
        #expect(fit("library", 900) == every(48))
        #expect(fit("library", SuiteSize.windowMinimum.width) == every(48))
        // Wide windows get the wider steps.
        #expect(fit("flare", 1100) == every(48))
        #expect(fit("flare", 1600) == every(80))
        #expect(fit("design", 1600) == every(80))
    }

    @Test func beforeTheWindowIsMeasuredOnlyTheCurrentItemShows() {
        #expect(fit("library", 0) == SwitcherToolbarFit(spacing: 32, showsEveryItem: false))
        #expect(
            AppSwitcher.toolbarFit(windowWidth: -1, itemCount: 0, documentActions: [], actions: [])
                == SwitcherToolbarFit(spacing: 32, showsEveryItem: false))
    }

    @Test func givingWayKeepsTheCurrentItem() {
        let state = AppSwitcherState.placeholder(processName: "LibraryApp")
        #expect(state.shownItems(everyItem: true).map(\.id) == ["home", "flare", "design", "photo", "library", "halo"])
        #expect(state.shownItems(everyItem: false).map(\.id) == ["library"])
        // With no current app, the first item keeps the row (and `suite.switcher`) on screen.
        #expect(AppSwitcherState.placeholder(processName: "xctest").shownItems(everyItem: false).map(\.id) == ["home"])
        let empty = AppSwitcherState(items: [], current: nil, onSelect: { _ in })
        #expect(empty.shownItems(everyItem: false).isEmpty)
    }

    @Test func theRowLeavesBothToolbarEndsTheirRoom() {
        // Every window from the minimum to 1600 pt, with each toolbar: nothing goes into the overflow.
        for name in Self.toolbars.keys.sorted() {
            for width in stride(from: SuiteSize.windowMinimum.width, through: 1600, by: SuiteSpacing.s) {
                let chosen = fit(name, width)
                let label = "\(name) at \(width) pt"
                let shown = chosen.showsEveryItem ? 6 : 1
                #expect(fits(name, width: width, spacing: chosen.spacing, items: shown), "\(label)")
                if chosen.showsEveryItem, let wider = AppSwitcher.spacingSteps.last(where: { $0 > chosen.spacing }) {
                    // The widest step that fits.
                    #expect(!fits(name, width: width, spacing: wider), "\(label)")
                } else if !chosen.showsEveryItem {
                    // It gives way only when even the compact row doesn't fit.
                    #expect(!fits(name, width: width, spacing: AppSwitcher.compactSpacing), "\(label)")
                }
            }
        }
    }

    /// The measured toolbar, worked out here rather than with AppSwitcher.rowEnd: icon-only
    /// buttons 36 pt each, the sidebar toggle and inspector toggle on top of `name`'s actions; the
    /// row is centered in the window unless that overlaps the leading end, then starts there, and it
    /// must end before the trailing buttons, their clearance and the safety margin.
    private func fits(_ name: String, width: CGFloat, spacing: CGFloat, items: Int = 6) -> Bool {
        let toolbar = Self.toolbars[name] ?? (docs: [], actions: [])
        let room = AppSwitcher.toolbarButtonRoom
        let leadingEnd = SuiteSize.sidebarWidth.ideal + CGFloat(1 + toolbar.docs.count) * room + AppSwitcher.titleRoom
        let trailingStart = width - CGFloat(toolbar.actions.count + 1) * room - AppSwitcher.trailingClearance
            - AppSwitcher.safetyMargin
        let row = CGFloat(items) * spacing
        return max(width / 2 - row / 2, leadingEnd) + row <= trailingStart
    }

    @Test func theCapsuleNeverReachesANeighboursIcon() {
        let widths = AppSwitcher.spacingSteps.map { AppSwitcher.capsuleWidth(spacing: $0) }
        let expected: [CGFloat] = [90, 90, 66, 50]
        let matches = widths.count == expected.count && zip(widths, expected).allSatisfy { pair in
            Self.same(pair.0, pair.1)
        }
        #expect(matches, "\(widths)")
        #expect(Self.same(AppSwitcher.capsuleWidth(spacing: AppSwitcher.compactSpacing), 34))
        #expect(AppSwitcher.capsuleHeight(spacing: AppSwitcher.compactSpacing) == SuiteSize.toolButton)
        #expect(AppSwitcher.spacingSteps.allSatisfy { AppSwitcher.capsuleHeight(spacing: $0) == 48 })
        for spacing in AppSwitcher.spacingSteps + [AppSwitcher.compactSpacing] {
            let capsule = AppSwitcher.capsuleWidth(spacing: spacing)
            // A neighbour's icon starts spacing − icon / 2 from this item's center.
            #expect(capsule / 2 + SuiteSpacing.xs <= spacing - SuiteSize.switcherIcon / 2, "\(spacing)")
            #expect(capsule >= AppSwitcher.capsuleHeight(spacing: spacing), "\(spacing)")
            #expect(capsule <= SuiteSize.switcherCapsule.width, "\(spacing)")
        }
    }

    /// Whether two toolbar widths match, within a rounding. Both sides are CGFloat, so an
    /// arithmetic expected value (`36 + 48 + 8`) can't be inferred as Int by `#expect`, which
    /// captures each side of `==` on its own (run 38989698445: `92.0 == 92` failed).
    static func same(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < 0.001
    }

    @MainActor
    @Test func theEnvironmentDefaultsToNoSwitcher() {
        #expect(EnvironmentValues().suiteSwitcher == nil)
    }
}
