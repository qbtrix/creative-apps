// AppSwitcherTests.swift: the app switcher's items and placeholder
// (AppSwitcher.swift). The placeholder lists Home and the five apps in order
// with their shortcuts, every item disabled with its reason; the current item
// follows the running executable; the tooltip names the app and its shortcut
// and then the reason; the identifiers are unique; the spacing steps run from
// the ideal down to the minimum; the toolbar spacing leaves Flare's, Halo's,
// Library's and the editor gallery's toolbar buttons their room; the capsule
// never reaches a neighbour's icon. macOS only.
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

    @Test func theToolbarSpacingFitsEachAppsWindow() {
        // Flare: the sidebar toggle; New Animation, New Sample Animation, Delete Layer and the inspector toggle.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1000, itemCount: 6, leadingButtons: 1, trailingButtons: 4) == 48)
        // Halo: New Composition… and the inspector toggle.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1000, itemCount: 6, leadingButtons: 1, trailingButtons: 2) == 48)
        // Library: the inspector toggle only, at its launch width and at the window minimum.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1000, itemCount: 6, leadingButtons: 1, trailingButtons: 1) == 48)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 900, itemCount: 6, leadingButtons: 1, trailingButtons: 1) == 40)
        #expect(
            AppSwitcher.toolbarSpacing(
                windowWidth: SuiteSize.windowMinimum.width, itemCount: 6, leadingButtons: 1, trailingButtons: 1) == 40)
        // The editor gallery at 1024 × 737: two document actions, six actions and the inspector toggle.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1024, itemCount: 6, leadingButtons: 3, trailingButtons: 7) == 40)
        // Wide windows get the wider steps.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1100, itemCount: 6, leadingButtons: 1, trailingButtons: 4) == 64)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1600, itemCount: 6, leadingButtons: 1, trailingButtons: 4) == 80)
    }

    @Test func theToolbarSpacingIsTheMinimumBeforeTheWindowIsMeasured() {
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 0, itemCount: 6, leadingButtons: 1, trailingButtons: 1) == 40)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: -1, itemCount: 0, leadingButtons: -1, trailingButtons: -1) == 40)
    }

    @Test func theRowLeavesBothToolbarEndsTheirRoom() {
        // Every window from the minimum to 1600 pt, with Flare's, Halo's, Library's and the gallery's buttons.
        let toolbars = [(1, 4), (1, 2), (1, 1), (3, 7)]
        for (leadingButtons, trailingButtons) in toolbars {
            for width in stride(from: SuiteSize.windowMinimum.width, through: 1600, by: SuiteSpacing.s) {
                let spacing = AppSwitcher.toolbarSpacing(
                    windowWidth: width, itemCount: 6, leadingButtons: leadingButtons, trailingButtons: trailingButtons)
                #expect(AppSwitcher.spacingSteps.contains(spacing))
                let trailing = CGFloat(trailingButtons) * AppSwitcher.toolbarButtonRoom
                let leading = SuiteSize.sidebarWidth.ideal + CGFloat(leadingButtons) * AppSwitcher.toolbarButtonRoom
                    + AppSwitcher.titleRoom
                let row = 6 * spacing
                // Centered on the window, the row ends before the trailing buttons start.
                #expect(width / 2 + row / 2 <= width - trailing, "\(width) pt, \(trailingButtons) trailing")
                // Above the minimum step it also starts after the leading end.
                if spacing > SuiteSize.switcherSpacingMinimum {
                    #expect(width / 2 - row / 2 >= leading, "\(width) pt, \(leadingButtons) leading")
                }
            }
        }
    }

    @Test func theCapsuleNeverReachesANeighboursIcon() {
        #expect(AppSwitcher.spacingSteps.map { AppSwitcher.capsuleWidth(spacing: $0) } == [90, 90, 66, 50])
        for spacing in AppSwitcher.spacingSteps {
            let capsule = AppSwitcher.capsuleWidth(spacing: spacing)
            // A neighbour's icon starts spacing − icon / 2 from this item's center.
            #expect(capsule / 2 + SuiteSpacing.xs <= spacing - SuiteSize.switcherIcon / 2, "\(spacing)")
            #expect(capsule >= SuiteSize.switcherCapsule.height, "\(spacing)")
            #expect(capsule <= SuiteSize.switcherCapsule.width, "\(spacing)")
        }
    }

    @MainActor
    @Test func theEnvironmentDefaultsToNoSwitcher() {
        #expect(EnvironmentValues().suiteSwitcher == nil)
    }
}
