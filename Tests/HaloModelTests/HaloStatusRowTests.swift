// HaloStatusRowTests.swift: the viewer status row's shapes, widest first,
// each keeping the transport's History button, the layer count dropping
// first and the zoom pill before the timecode (#4449). Linux and macOS.
@testable import HaloModel
import Testing

/// The facts and controls a row shows, as a set, so one row can be compared with the next.
private func shown(_ row: HaloStatusRow) -> Set<String> {
    var set: Set<String> = ["transport", "size"]
    if row.layers { set.insert("layers") }
    if row.transportInBar { set.insert("inBar") }
    if row.zoom { set.insert("zoom") }
    if row.timecode { set.insert("timecode") }
    if row.history { set.insert("history") }
    return set
}

@Test func everyStatusRowKeepsHistory() {
    let rows = HaloStatusRow.fallbacks
    #expect(rows == [.wide, .noLayers, .leading, .leadingNoZoom, .bare])
    for (index, row) in rows.enumerated() {
        #expect(row.history, "row \(index) drops History, so it can't be opened at that width")
    }
}

@Test func statusRowsNarrowOneFactAtATime() throws {
    let rows = HaloStatusRow.fallbacks
    let first = try #require(rows.first)
    #expect(shown(first) == ["transport", "size", "layers", "inBar", "zoom", "timecode", "history"])
    for (wider, narrower) in zip(rows, rows.dropFirst()) {
        let (a, b) = (shown(wider), shown(narrower))
        #expect(b.isStrictSubset(of: a), "\(b.sorted()) isn't narrower than \(a.sorted())")
        #expect(a.count - b.count == 1, "\(a.subtracting(b).sorted()) drop at once")
    }
}

@Test func statusRowDropsLayersThenPillThenZoomThenTimecode() {
    let rows = HaloStatusRow.fallbacks.map(shown)
    let dropped = zip(rows, rows.dropFirst()).flatMap { $0.subtracting($1).sorted() }
    #expect(dropped == ["layers", "inBar", "zoom", "timecode"])
}

@Test func statusRowPillsHelpNamesOnlyShownPills() {
    #expect(HaloStatusRow.leading.pillsHelp == HaloComposition.viewerPillsHelp)
    #expect(HaloStatusRow.leadingNoZoom.pillsHelp == "The composition size in pixels.")
    #expect(!HaloStatusRow.bare.pillsHelp.contains("zoom"))
}
