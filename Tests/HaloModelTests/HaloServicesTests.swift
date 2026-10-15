// HaloServicesTests.swift: every service acts or says why. Each check is an
// invariant that stays true as features land their live types: a live
// service either has no help (it works; its own contract suite proves it) or
// names its issue and refuses every write with `.notBuilt`, changing nothing.
// So a feature replacing a Live/ file never edits this one. Runs on Linux and
// macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HaloModel
import Testing

/// Whether `help` is a stub's: non-empty and naming an issue ("#37").
func namesAnIssue(_ help: String) -> Bool {
    help.split(separator: "#").dropFirst().contains { $0.first?.isNumber == true }
}

/// Runs `write` on a copy of `composition`; true when it threw `.notBuilt`
/// and left the copy equal.
func refusesAsNotBuilt(_ composition: HaloComposition, _ write: (inout HaloComposition) throws -> Void) -> Bool {
    var copy = composition
    do { try write(&copy) } catch let HaloEditError.notBuilt(what) { return !what.isEmpty && copy == composition } catch {
        return false
    }
    return false
}

@Test func everyFakeServiceWorks() {
    for (name, service) in HaloServices.fake.all {
        #expect(service.unavailableHelp == nil, "fake \(name) says it can't act")
    }
    #expect(HaloServices.fake.text != nil)
}

@Test func everyLiveServiceWorksOrNamesItsIssue() {
    for (name, service) in HaloServices.live.all {
        guard let help = service.unavailableHelp else { continue }
        #expect(namesAnIssue(help), "live \(name)'s help \"\(help)\" names no issue")
    }
}

@Test func everyUnbuiltLiveWriteRefusesAndChangesNothing() {
    let live = HaloServices.live, comp = keyedPair()
    if live.keying.unavailableHelp != nil {
        let k = live.keying
        #expect(refusesAsNotBuilt(comp) { try k.setValue(10, for: .x, of: "s", at: 0, in: &$0) })
        #expect(refusesAsNotBuilt(comp) { try k.toggleAnimation(.x, of: "s", at: 0, in: &$0) })
        #expect(refusesAsNotBuilt(comp) { try k.toggleKey(.x, of: "s", at: 0, in: &$0) })
        #expect(refusesAsNotBuilt(comp) { try k.setParent("n", of: "s", at: 0, in: &$0) })
    }
    if live.dragging.unavailableHelp != nil {
        let d = live.dragging
        #expect(refusesAsNotBuilt(comp) { try d.commitMove("s", by: HaloPoint(x: 10, y: 0), at: 0, in: &$0) })
    }
    if live.easing.unavailableHelp != nil {
        let key = HaloKeyRef(layerID: "s", property: .x, frame: 0), e = live.easing
        #expect(refusesAsNotBuilt(comp) { try e.setEasing(.linear, on: [key], in: &$0) })
    }
    if live.rendering.unavailableHelp != nil {
        let r = live.rendering, list = FakeFrameDrawing().drawList(comp, at: 0)
        #expect(refusesAsNotBuilt(comp) { _ in _ = try r.render(list, width: 40, height: 20, text: nil) })
    }
    if live.compositionRendering.unavailableHelp != nil {
        let r = live.compositionRendering
        #expect(refusesAsNotBuilt(comp) { _ in _ = try r.plan(comp, settings: HaloRenderSettings(format: .movie)) })
    }
    if live.files.unavailableHelp != nil {
        let f = live.files
        #expect(refusesAsNotBuilt(comp) { _ in _ = try f.encode(HaloDocumentState()) })
        #expect(refusesAsNotBuilt(comp) { _ in _ = try f.decode(Data(#"{"format":"halo","version":1}"#.utf8)) })
    }
}

@Test func anUnbuiltLiveHistoryKeepsNoSteps() {
    let history = HaloServices.live.history
    guard history.unavailableHelp != nil else { return }
    var h = HaloHistory()
    history.record("New Layer", before: HaloDocumentState(), coalesceKey: nil, in: &h)
    #expect(h == HaloHistory())
    #expect(history.undo(HaloDocumentState(), in: &h) == nil)
}
