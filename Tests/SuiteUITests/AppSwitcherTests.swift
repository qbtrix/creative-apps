// AppSwitcherTests.swift: the app switcher's items and placeholder
// (AppSwitcher.swift). The placeholder lists Home and the five apps in order
// with their shortcuts, every item disabled with its reason; the current item
// follows the running executable; the tooltip names the app and its shortcut
// and then the reason; the identifiers are unique; the spacing steps run from
// the ideal down to the minimum, then the compact step; the room model matches
// the toolbar positions measured in runs 38897404951 and 38938835086; the
// toolbar spacing leaves Flare's, Halo's, Library's, Design's and the editor
// gallery's toolbar buttons their room at their journey sizes, and gives way
// (the compact step) when no step fits; the capsule never reaches a
// neighbour's icon. macOS only.
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

    @Test func theRoomModelMatchesTheMeasuredToolbars() {
        // The row started at 423 to 424 pt after one leading button (Flare, Halo, Library, the
        // gallery's window page) and at 538 pt after Design's four; the model never says earlier.
        #expect(AppSwitcher.toolbarLeading(leadingButtons: 1) == 432)
        #expect(AppSwitcher.toolbarLeading(leadingButtons: 4) == 540)
        #expect(AppSwitcher.toolbarLeading(leadingButtons: 1) >= 424)
        #expect(AppSwitcher.toolbarLeading(leadingButtons: 4) >= 538)
        // Overflowed: Halo at 1000 pt with 80 (run 38897404951), Design at 1024 pt with 40 (run 38938835086).
        #expect(!fits(width: 1000, spacing: 80, leading: 1, trailing: 2))
        #expect(!fits(width: 1024, spacing: 40, leading: 4, trailing: 6))
        // Kept every button: Flare at 1000 pt and Halo at 880 pt with 48, Library at 900 pt with 40.
        #expect(fits(width: 1000, spacing: 48, leading: 1, trailing: 4))
        #expect(fits(width: 880, spacing: 48, leading: 1, trailing: 2))
        #expect(fits(width: 900, spacing: 40, leading: 1, trailing: 1))
    }

    @Test func theToolbarSpacingFitsEachAppsWindow() {
        // Flare: the sidebar toggle; New Animation, New Sample Animation, Delete Layer and the inspector toggle.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1000, itemCount: 6, leadingButtons: 1, trailingButtons: 4) == 48)
        // Halo: New Composition… and the inspector toggle, at its launch width, its layout sizes and the minimum.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1000, itemCount: 6, leadingButtons: 1, trailingButtons: 2) == 64)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1024, itemCount: 6, leadingButtons: 1, trailingButtons: 2) == 64)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 880, itemCount: 6, leadingButtons: 1, trailingButtons: 2) == 48)
        // Library (and the gallery's window page): the inspector toggle only.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1000, itemCount: 6, leadingButtons: 1, trailingButtons: 1) == 80)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 900, itemCount: 6, leadingButtons: 1, trailingButtons: 1) == 64)
        #expect(
            AppSwitcher.toolbarSpacing(
                windowWidth: SuiteSize.windowMinimum.width, itemCount: 6, leadingButtons: 1, trailingButtons: 1) == 48)
        // Design: New, Open and Save beside the title; Undo, Redo, Zoom Out, Fit, Zoom In and the
        // inspector toggle trailing. Its journeys run at 1000 pt and (the shell) 1024 × 768.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1024, itemCount: 6, leadingButtons: 4, trailingButtons: 6) == 32)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1000, itemCount: 6, leadingButtons: 4, trailingButtons: 6) == 32)
        // The editor gallery at 1024 × 737: two document actions, six actions and the inspector toggle.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1024, itemCount: 6, leadingButtons: 3, trailingButtons: 7) == 32)
        // Wide windows get the wider steps.
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1100, itemCount: 6, leadingButtons: 1, trailingButtons: 4) == 64)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1600, itemCount: 6, leadingButtons: 1, trailingButtons: 4) == 80)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 1600, itemCount: 6, leadingButtons: 4, trailingButtons: 6) == 80)
    }

    @Test func everyJourneyWindowKeepsItsToolbarButtons() {
        // (width, leading, trailing) for each app's journey windows: nothing goes into the overflow.
        let journeys: [(CGFloat, Int, Int)] = [
            (1000, 1, 4), (1000, 1, 2), (880, 1, 2), (1024, 1, 2), (1000, 1, 1), (900, 1, 1),
            (1000, 4, 6), (1024, 4, 6), (1024, 3, 7),
        ]
        for (width, leading, trailing) in journeys {
            let spacing = AppSwitcher.toolbarSpacing(
                windowWidth: width, itemCount: 6, leadingButtons: leading, trailingButtons: trailing)
            #expect(fits(width: width, spacing: spacing, leading: leading, trailing: trailing), "\(width) pt, \(leading)/\(trailing)")
        }
    }

    @Test func theToolbarSpacingIsCompactBeforeTheWindowIsMeasured() {
        #expect(AppSwitcher.toolbarSpacing(windowWidth: 0, itemCount: 6, leadingButtons: 1, trailingButtons: 1) == 32)
        #expect(AppSwitcher.toolbarSpacing(windowWidth: -1, itemCount: 0, leadingButtons: -1, trailingButtons: -1) == 32)
    }

    @Test func theRowLeavesBothToolbarEndsTheirRoom() {
        // Every window from the minimum to 1600 pt, with Flare's, Halo's, Library's, the gallery's and Design's buttons.
        let toolbars = [(1, 4), (1, 2), (1, 1), (3, 7), (4, 6)]
        for (leading, trailing) in toolbars {
            for width in stride(from: SuiteSize.windowMinimum.width, through: 1600, by: SuiteSpacing.s) {
                let spacing = AppSwitcher.toolbarSpacing(
                    windowWidth: width, itemCount: 6, leadingButtons: leading, trailingButtons: trailing)
                let label = "\(width) pt, \(leading)/\(trailing)"
                if AppSwitcher.spacingSteps.contains(spacing) {
                    // A step: its row fits, and the next wider step's doesn't.
                    #expect(fits(width: width, spacing: spacing, leading: leading, trailing: trailing), "\(label)")
                    if let wider = AppSwitcher.spacingSteps.last(where: { $0 > spacing }) {
                        #expect(!fits(width: width, spacing: wider, leading: leading, trailing: trailing), "\(label)")
                    }
                } else {
                    // No step fits, so the switcher gives way: the compact step.
                    #expect(spacing == AppSwitcher.compactSpacing, "\(label)")
                    #expect(!fits(width: width, spacing: SuiteSize.switcherSpacingMinimum, leading: leading, trailing: trailing), "\(label)")
                }
            }
        }
    }

    /// The measured toolbar, worked out here rather than with AppSwitcher.rowEnd: the row is
    /// centered in the window unless that overlaps the leading end, then starts there, and it must
    /// end before the trailing buttons and their clearance.
    private func fits(width: CGFloat, spacing: CGFloat, leading: Int, trailing: Int) -> Bool {
        let room = AppSwitcher.toolbarButtonRoom
        let leadingEnd = SuiteSize.sidebarWidth.ideal + CGFloat(leading) * room + AppSwitcher.titleRoom
        let trailingStart = width - CGFloat(trailing) * room - AppSwitcher.trailingClearance
        let row = 6 * spacing
        return max(width / 2 - row / 2, leadingEnd) + row <= trailingStart
    }

    @Test func theCapsuleNeverReachesANeighboursIcon() {
        #expect(AppSwitcher.spacingSteps.map { AppSwitcher.capsuleWidth(spacing: $0) } == [90, 90, 66, 50])
        #expect(AppSwitcher.capsuleWidth(spacing: AppSwitcher.compactSpacing) == 34)
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

    @MainActor
    @Test func theEnvironmentDefaultsToNoSwitcher() {
        #expect(EnvironmentValues().suiteSwitcher == nil)
    }
}
