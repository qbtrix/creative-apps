// HarnessFakeTests.swift: the harness Fakes (frame probe, control inventory,
// golden compare) behave as section 5.3 says, including what each gets wrong
// on purpose, so the live tests that rely on those gaps keep meaning
// something. No SwiftUI here. macOS only.
import Foundation
import SuiteUI
import Testing

@Test func fakeProbeReportsZeroFramesLateAndValidOnlyAtSixty() {
    var probe = FakeFrameProbe()
    for i in 0..<59 {
        probe.record(ProbeSample(series: "drag", eventTime: Double(i), shownAt: Double(i) + 0.5))
    }
    let short = probe.summary(of: "drag", refreshInterval: 1.0 / 60)
    #expect(short.count == 59)
    #expect(short.p50FramesLate == 0 && short.p95FramesLate == 0)
    #expect(!short.valid)
    probe.record(ProbeSample(series: "drag", eventTime: 59, shownAt: 59.5))
    let full = probe.summary(of: "drag", refreshInterval: 1.0 / 60)
    #expect(full.count == 60)
    #expect(full.p95FramesLate == 0)
    #expect(full.valid)
}

@Test func fakeProbeDocumentRoundTrips() throws {
    var probe = FakeFrameProbe()
    probe.record(ProbeSample(series: "s", eventTime: 0, shownAt: 0.016))
    probe.drew("scroll", at: 0)
    probe.drew("scroll", at: 1.0 / 60)
    probe.mark("fade-start", series: "chip", at: 0)
    probe.mark("fade-end", series: "chip", at: 0.14)
    let data = try probe.encoded(refreshInterval: 1.0 / 60)
    let doc = try JSONDecoder().decode(ProbeDocument.self, from: data)
    #expect(doc == probe.document(refreshInterval: 1.0 / 60))
    #expect(doc.marks.map(\.name) == ["fade-start", "fade-end"])
    #expect(doc.intervals["scroll"]?.count == 1)
    #expect(doc.latency["s"]?.count == 1)
}

@Test func fakeInventoryFlagsAReasonlessDisabledEntryButNoDuplicate() throws {
    var inventory = FakeControlInventory()
    inventory.register(ControlEntry(id: "b.export", enabled: true, role: "primary"))
    inventory.register(ControlEntry(id: "a.pen", enabled: false))
    inventory.register(ControlEntry(id: "c.dup", enabled: true))
    inventory.register(ControlEntry(id: "c.dup", enabled: true))
    #expect(inventory.violations() == ["a.pen"])
    #expect(inventory.document().controls.map(\.id) == ["a.pen", "b.export", "c.dup"])
    let decoded = try JSONDecoder().decode(ControlDocument.self, from: inventory.encoded())
    #expect(decoded == inventory.document())
    inventory.unregister("a.pen")
    #expect(inventory.violations().isEmpty)
}

@Test func fakeGoldenFailsOneChangedByteWithShareOneAndNoDiff() {
    let baseline = RGBAImage(width: 2, height: 2, bytes: [UInt8](repeating: 128, count: 16))
    var actual = baseline
    actual.bytes[5] = 129
    let fake = FakeGoldenComparing()
    let same = fake.compare(baseline, to: baseline, tolerance: .standard)
    #expect(same.passes && same.share == 0 && same.diff == nil)
    let changed = fake.compare(actual, to: baseline, tolerance: .standard)
    #expect(!changed.passes)
    #expect(changed.share == 1)
    #expect(changed.diff == nil)
    #expect(GoldenTolerance.standard == GoldenTolerance(channel: 2, maxShare: 0.005))
}
