// SuiteSidebarSlotTests.swift: SuiteWindow's sidebar slot is one container carrying `suite.sidebar`, even
// when an app's sidebar is a bare List. Without the container the identifier landed on the List's outline,
// which hosted XCUITest reported not hittable (#2702, the gallery's editor-window page), while Design's and
// Photo's tabbed sidebars, a group, passed the same check.
import AppKit
import SwiftUI
import Testing
@testable import SuiteUI

@MainActor @Suite struct SuiteSidebarSlotTests {
    @Test func aBareListSidebarSitsInAGroupCarryingTheSidebarIdentifier() async throws {
        let window = RenderBudgetWindow(
            SuiteGallery(GalleryRequest(page: "editor-window")), size: CGSize(width: 1024, height: 700))
        defer { window.close() }
        #expect(await window.element("suite.sidebar") != nil)
        #expect(window.role("suite.sidebar") == .group)
        #expect(window.element(.outline, in: "suite.sidebar") != nil)
    }
}
