// HaloKeyDeleteBatchTests.swift: Delete Keyframes' one-pass batch (#5988)
// against the per-key toggle it replaced. The live `deleteKeys` must leave
// every track exactly as `toggleKey` on each picked key would: a track left
// with two keys or more keeps them, one left with one goes static at it, one
// left with none at its first key. Linux and macOS.
@testable import HaloModel
import Testing

/// The live keying with the protocol's default `deleteKeys`: one `toggleKey` per key.
private struct ToggleEachKeying: PropertyKeying {
    let live = LivePropertyKeying()
    func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] {
        live.rows(for: layerID, in: composition, at: frame)
    }
    func setValue(_ v: Double, for p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        try live.setValue(v, for: p, of: id, at: f, in: &c)
    }
    func toggleAnimation(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        try live.toggleAnimation(p, of: id, at: f, in: &c)
    }
    func toggleKey(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        try live.toggleKey(p, of: id, at: f, in: &c)
    }
    func setParent(_ parentID: String?, of id: String, at f: Int, in c: inout HaloComposition) throws {
        try live.setParent(parentID, of: id, at: f, in: &c)
    }
}

/// Every key of every animated track in `comp`.
private func allKeys(_ comp: HaloComposition) -> [HaloKeyRef] {
    comp.layers.flatMap { layer in
        layer.tracks.filter { $0.value.count >= 2 }.flatMap { name, track in
            track.compactMap { k in HaloProperty(rawValue: name).map { HaloKeyRef(layerID: layer.id, property: $0, frame: k.frame) } }
        }
    }
}

/// Picks that cover each outcome: everything, every other key, all but each
/// track's first, all but its last, and only each track's middle keys.
private func pickings(_ comp: HaloComposition) -> [String: Set<HaloKeyRef>] {
    let keys = allKeys(comp)
    let byTrack = Dictionary(grouping: keys) { "\($0.layerID)/\($0.property.rawValue)" }
        .mapValues { $0.sorted { $0.frame < $1.frame } }
    return [
        "all": Set(keys),
        "every other": Set(keys.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)),
        "all but first": Set(byTrack.values.flatMap { $0.dropFirst() }),
        "all but last": Set(byTrack.values.flatMap { $0.dropLast() }),
        "middles": Set(byTrack.values.flatMap { $0.dropFirst().dropLast() }),
    ]
}

@Test(arguments: ["parented", "keyed", "reference", "crowd"])
func batchDeleteMatchesTogglingEachKey(_ fixture: String) throws {
    let comp = try #require(HaloFixtures.project(fixture)?.compositions.first)
    for (name, picked) in pickings(comp) {
        var batch = comp, each = comp
        try LivePropertyKeying().deleteKeys(picked, in: &batch)
        try ToggleEachKeying().deleteKeys(picked, in: &each)
        #expect(batch == each, "\(fixture), \(name): the batch delete left different tracks")
    }
}

/// A key that isn't there and an unknown layer change nothing.
@Test func batchDeleteSkipsMissingKeys() throws {
    let comp = try #require(HaloFixtures.project("parented")?.compositions.first)
    let ball = try #require(comp.layers.first { $0.name == "Ball" }).id
    var c = comp
    LivePropertyKeying().deleteKeys(
        [HaloKeyRef(layerID: ball, property: .x, frame: 5), HaloKeyRef(layerID: "nope", property: .x, frame: 0)], in: &c)
    #expect(c == comp)
}
