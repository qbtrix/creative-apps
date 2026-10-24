// HaloLayerStyleMenuTests.swift: layer-styles HY-2, the Layer menu's style items by id. Layer Style… opens the
// panel at Drop Shadow on a selected layer; Copy, Paste and Clear Layer Style each say why they can't run (no
// layer, no style, nothing copied, or the kernel's body not built yet), so none is a dead control. Linux and macOS.
@testable import HaloModel
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct HaloLayerStyleMenuTests {
    /// `three-layers` with Title selected and styled `lifted`, written straight into the document (setStyle is HY-5's).
    static func styled() throws -> HaloProject {
        var project = try HaloLayerStyleTests.selecting("Title")
        let c = try #require(project.document.compositions.firstIndex { $0.id == project.document.selectedCompositionID })
        let l = try #require(project.document.compositions[c].layers.firstIndex { $0.id == project.document.selectedLayerID })
        project.document.compositions[c].layers[l].style = HaloLayerStyleTests.lifted
        #expect(project.styleSelection == HaloLayerStyleTests.lifted)
        return project
    }

    @Test func theMenuItemsAreTheFourIds() {
        #expect(HaloProject.styleMenuIDs == ["style.panel", "style.copy", "style.paste", "style.clear"])
        #expect(HaloProject.styleMenuIDs.allSatisfy { HaloProject.catalog.spec($0) != nil })
    }

    @Test func layerStyleOpensThePanelAtDropShadow() throws {
        var project = try HaloLayerStyleTests.selecting("Title")
        #expect(project.styleMenuHelp("style.panel") == nil, "Layer Style… is live on a selected layer")
        #expect(project.runStyleMenu("style.panel") == nil, "Layer Style… returns nothing")
        #expect(project.stylePanel == .dropShadow)
        project.runStyle(.show(nil))
        #expect(project.stylePanel == nil, "Done closes it")
    }

    @Test func noLayerDisablesEveryItem() throws {
        var project = try HaloLayerStyleTests.selecting("Title")
        project.document.selectedLayerID = nil
        for id in HaloProject.styleMenuIDs { #expect(project.styleMenuHelp(id) == StyleRules.noLayerHelp, "\(id)") }
        project.runStyle(.show(.dropShadow))
        #expect(project.stylePanel == nil, "the panel needs a layer")
    }

    @Test func copyClearAndPasteSayWhy() throws {
        let plain = try HaloLayerStyleTests.selecting("Title")
        #expect(plain.styleMenuHelp("style.copy") == "This layer has no style to copy.")
        #expect(plain.styleMenuHelp("style.clear") == "This layer has no style to clear.")
        #expect(plain.styleMenuHelp("style.paste") == HaloProject.nothingCopied)
        let styled = try Self.styled()
        let pasted = JSONValue.object(["effects": .array([]), "fillOpacity": .number(1)])
        for id in ["style.copy", "style.clear"] { #expect(styled.styleMenuHelp(id)?.contains("layer-styles LS-6") == true, "\(id)") }
        #expect(styled.styleMenuHelp("style.paste", pasted: pasted)?.contains("layer-styles LS-6") == true)
    }

    @Test func runningAnItemByIdChangesNothingWhileItIsAStub() throws {
        var project = try Self.styled()
        let before = project.document
        #expect(project.runStyleMenu("style.clear") == nil)
        #expect(project.document == before)
    }

    @Test func theSpecsReadTheWindowAndThePasteboard() throws {
        let noWindow = HaloStyleMenuState(project: nil, pasted: nil)
        #expect(HaloProject.styleMenuIDs.allSatisfy { HaloStyleMenuState.spec($0).availability(noWindow).why == HaloMenuState.noWindow })
        let project = try HaloLayerStyleTests.selecting("Title")
        let open = HaloStyleMenuState(project: project, pasted: nil)
        #expect(HaloStyleMenuState.spec("style.panel").availability(open) == .available)
        #expect(HaloStyleMenuState.spec("style.paste").availability(open).why == HaloProject.nothingCopied)
        #expect(HaloStyleMenuState.spec("style.panel").title == "Layer Style…")
        #expect(HaloStyleMenuState.done.availability(noWindow) == .available, "Done always closes the panel")
    }
}
