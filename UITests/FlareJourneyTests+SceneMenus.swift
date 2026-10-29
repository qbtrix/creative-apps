// FlareJourneyTests+SceneMenus.swift: the sidebar rows' context menus
// (layers-files LF-2, #2187). On `-FlareSample bounce` (live services): a
// right-click on Shadow lists Rename, Hide Layer, Lock Layer, Duplicate Layer
// and Delete Layer; Delete Layer takes Shadow out and ⌘Z brings it back. Hide
// Layer on Ball flips its eye toggle and is one ⌘Z. A right-click on Scene 1,
// the only scene, lists Rename and Delete Scene, which is off. One shot per
// step, `flare-row-menus-<step>`.
import XCTest

final class FlareSceneMenuJourneys: XCTestCase {
    @MainActor func testRowContextMenus() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(flare.element("suite.sidebar").waitForExistence(timeout: 10), "the window has no sidebar")

        // 1. Shadow's menu holds the five layer items; Delete Layer removes it, one ⌘Z.
        let shadow = flare.sidebarRow("Shadow")
        XCTAssert(shadow.waitForExistence(timeout: 5), "the sidebar has no Shadow row")
        shadow.rightClick()
        for title in ["Rename", "Hide Layer", "Lock Layer", "Duplicate Layer"] {
            XCTAssert(flare.app.menuItems[title].waitForExistence(timeout: 5), "Shadow's menu has no \(title)")
        }
        let delete = flare.app.menuItems["Delete Layer"]
        XCTAssert(delete.waitForExistence(timeout: 5), "Shadow's menu has no Delete Layer")
        flare.shot("row-menus-1-layer-menu")
        delete.click()
        XCTAssert(waitFor { !flare.sidebarRow("Shadow").exists }, "Delete Layer left Shadow in the sidebar")
        flare.press(character: "z", .command)
        XCTAssert(flare.sidebarRow("Shadow").waitForExistence(timeout: 5), "⌘Z didn't bring Shadow back")
        flare.shot("row-menus-1-deleted-and-undone")

        // 2. Hide Layer on Ball flips its eye, one ⌘Z.
        flare.sidebarRow("Ball").rightClick()
        let hide = flare.app.menuItems["Hide Layer"]
        XCTAssert(hide.waitForExistence(timeout: 5), "Ball's menu has no Hide Layer")
        hide.click()
        let eye = flare.element("suite.sidebar.ball.visible")
        XCTAssert(eye.waitForExistence(timeout: 5), "Ball has no visible toggle")
        XCTAssert(waitFor { eye.label == "Show Layer" }, "Hide Layer left Ball's eye at \(eye.label)")
        flare.press(character: "z", .command)
        XCTAssert(waitFor { eye.label == "Hide Layer" }, "⌘Z left Ball's eye at \(eye.label)")
        flare.shot("row-menus-2-hidden-and-undone")

        // 3. The only scene's menu: Rename, and Delete Scene off.
        flare.sidebarRow("Scene 1").rightClick()
        let deleteScene = flare.app.menuItems["Delete Scene"]
        XCTAssert(deleteScene.waitForExistence(timeout: 5), "Scene 1's menu has no Delete Scene")
        XCTAssert(flare.app.menuItems["Rename"].exists, "Scene 1's menu has no Rename")
        XCTAssertFalse(deleteScene.isEnabled, "Delete Scene is on for the only scene")
        flare.shot("row-menus-3-scene-menu")
        flare.press(.escape)
    }

    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}
