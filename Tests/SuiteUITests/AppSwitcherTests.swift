// AppSwitcherTests.swift: the app switcher's items and placeholder
// (AppSwitcher.swift). The placeholder lists Home and the five apps in order
// with their shortcuts, every item disabled with its reason; the current item
// follows the running executable; the tooltip names the app and its shortcut
// and then the reason; the identifiers are unique; the spacing steps run from
// the ideal down to the minimum. macOS only.
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

    @MainActor
    @Test func theEnvironmentDefaultsToNoSwitcher() {
        #expect(EnvironmentValues().suiteSwitcher == nil)
    }
}
