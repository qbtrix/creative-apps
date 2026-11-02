// HaloFilters+Kernel.swift (adjust-everywhere AJ-12): Halo's project as SuiteImaging's AdjustTarget, per selected
// layer. A layer keeps an ordered list of filters and kinds (`HaloLayer.filters`, each key at most once) that
// LiveFrameRendering runs on that layer's pixels before its blend, so a frame and a render draw it alike. A filter
// command edits its entry in place (keeping hidden) or appends it; the kinds keep their places. `filter.set-hidden`,
// `filter.remove` and `filter.move` (AJ-13) change the list for the inspector's rows. Each change is one step through
// `edit`. Looks stay Photo's and Library's: Halo lists no look commands. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteImaging
import SuiteKernel
import SuiteModel

/// One entry of a layer's list: a filter or a kind, and whether it is hidden.
public struct HaloLayerFilter: Hashable, Codable, Sendable, Identifiable {
    public enum Step: Hashable, Codable, Sendable { case filter(ImagingFilter), kind(ImagingKind) }
    public var step: Step
    /// A hidden entry stays in the list and draws nothing.
    public var hidden: Bool
    public init(_ step: Step, hidden: Bool = false) { (self.step, self.hidden) = (step, hidden) }

    /// The entry's key in its list: the filter's id, or "black-and-white", "invert".
    public var id: String {
        switch step {
        case .filter(let f): f.id
        case .kind(.blackAndWhite): "black-and-white"
        case .kind(.invert): "invert"
        }
    }

    /// "Gaussian Blur", "Invert": the row's name.
    public var title: String { if case .filter(let f) = step { f.title } else if case .kind(let k) = step { k.title } else { "" } }

    /// Every key a list can hold.
    public static let ids = ImagingFilter.ids + ["black-and-white", "invert"]

    /// `pixels` through each of `steps` that isn't hidden, in order, at `scale` (pixel lengths shrink with the
    /// frame, percents don't). Throws the filter's or the channel mixer's refusal.
    public static func run(_ steps: [HaloLayerFilter], on pixels: PixelBuffer, scale: Double) throws -> PixelBuffer {
        var out = pixels
        for entry in steps where !entry.hidden {
            switch entry.step {
            case .filter(let f):
                out = try FilterRules.apply(scaled(f, scale), to: out, coverage: nil)
            case .kind(let k):  // the kinds' CPU twin, on CoreRaster's own channel mixer and invert
                for made in AdjustKinds.adjustments([k]) {
                    switch made {
                    case .channelMixer(let m): out = try out.channelMixer(m)
                    case .invert: out = out.inverted()
                    default: continue
                    }
                }
            }
        }
        return out
    }

    /// `f` for a frame drawn at `s` of the composition's size.
    static func scaled(_ f: ImagingFilter, _ s: Double) -> ImagingFilter {
        switch f {
        case .gaussianBlur(let r): .gaussianBlur(radius: r * s)
        case .motionBlur(let d, let l): .motionBlur(degrees: d, distance: l * s)
        case .sharpen(let a, let r, let t): .sharpen(amount: a, radius: max(r * s, ImagingFilter.sharpenRadius.lowerBound), threshold: t)
        case .reduceNoise, .addNoise: f
        }
    }
}

extension HaloProject: AdjustTarget {
    /// Why nothing can be filtered: no composition, no layer, or a null.
    static let noFilterComposition = "Make or open a composition to filter.",
        noFilterLayer = "Select a layer to filter.",
        nullTakesNoFilter = "A null layer has no pixels to filter."

    public var adjustHelp: String? {
        guard selectedComposition != nil else { return Self.noFilterComposition }
        guard let layer = selectedLayer else { return Self.noFilterLayer }
        return layer.kind == .null ? Self.nullTakesNoFilter : nil
    }

    public var filterHelp: String? { nil }
    public var currentLook: LookPreset { LookPreset(id: "current", name: "Current", kinds: kinds) }

    /// The selected layer's kinds, in list order.
    public var kinds: [ImagingKind] {
        (selectedLayer?.filters ?? []).compactMap { if case .kind(let k) = $0.step { k } else { nil } }
    }

    /// Keeps each kind entry still in `k` where it is (with its new values), drops the rest, appends the new ones.
    public mutating func setKinds(_ k: [ImagingKind], name: String) throws {
        try editFilters("adjust", name) { list in
            let keys = k.map { HaloLayerFilter(.kind($0)).id }
            list = list.compactMap { entry in
                guard case .kind = entry.step else { return entry }
                guard let at = keys.firstIndex(of: entry.id) else { return nil }
                return HaloLayerFilter(.kind(k[at]), hidden: entry.hidden)
            }
            for kind in k where !list.contains(where: { $0.id == HaloLayerFilter(.kind(kind)).id }) {
                list.append(HaloLayerFilter(.kind(kind)))
            }
        }
    }

    public mutating func applyFilter(_ f: ImagingFilter, name: String) throws { try setLayerFilter(f, name: name) }
    public mutating func applyLook(_ l: LookPreset, name: String) throws { try setKinds(l.kinds, name: name) }

    /// Halo saves no looks of its own.
    public var looks: any PresetStoring { Self.noLooks }
    static let noLooks = FakePresetStore()

    /// Replaces the entry with `f`'s id in place, keeping hidden, or appends it: one step named `name`, merged into
    /// the newest with the same `coalesceKey` (a slider drag).
    public mutating func setLayerFilter(_ f: ImagingFilter, name: String, coalesceKey: String? = nil) throws {
        try editFilters("filter.\(f.id)", name, coalesceKey: coalesceKey) { list in
            if let at = list.firstIndex(where: { $0.id == f.id }) { list[at].step = .filter(f) } else { list.append(HaloLayerFilter(.filter(f))) }
        }
    }

    /// Hides or shows the entry `id`: one step.
    public mutating func setLayerFilterHidden(_ id: String, _ hidden: Bool) throws {
        try editFilters("filter.set-hidden", hidden ? "Hide Filter" : "Show Filter") { list in
            list[try Self.entry(id, in: list)].hidden = hidden
        }
    }

    /// Removes the entry `id`: one step.
    public mutating func removeLayerFilter(_ id: String) throws {
        try editFilters("filter.remove", "Remove Filter") { list in list.remove(at: try Self.entry(id, in: list)) }
    }

    /// Moves the entry `id` to `index` (0 runs first, clamped to the list): one step.
    public mutating func moveLayerFilter(_ id: String, to index: Int) throws {
        try editFilters("filter.move", "Move Filter") { list in
            let entry = list.remove(at: try Self.entry(id, in: list))
            list.insert(entry, at: min(max(index, 0), list.count))
        }
    }

    static func entry(_ id: String, in list: [HaloLayerFilter]) throws -> Int {
        if let at = list.firstIndex(where: { $0.id == id }) { return at }
        throw HaloEditError.notBuilt("A filter \u{201C}\(id)\u{201D} on this layer")
    }

    /// One step named `name` that changes the selected layer's list; refused in `adjustHelp`'s words.
    mutating func editFilters(_ id: String, _ name: String, coalesceKey: String? = nil,
                              _ change: (inout [HaloLayerFilter]) throws -> Void) throws {
        if let why = adjustHelp { throw CatalogError.unavailable(id: id, why: why) }
        let done = edit(name, control: "halo.inspector.filters", coalesceKey: coalesceKey) { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID }),
                  let l = doc.compositions[c].layers.firstIndex(where: { $0.id == doc.selectedLayerID })
            else { throw HaloEditError.noLayerSelected }
            try change(&doc.compositions[c].layers[l].filters)
        }
        if !done { throw CatalogError.failed(id: id, message: refusal?.message ?? "That change couldn't be made.") }
    }

    struct FilterID: Codable, Sendable { var id: String }
    struct FilterHidden: Codable, Sendable { var id: String; var hidden: Bool }
    struct FilterMove: Codable, Sendable { var id: String; var index: Int }

    /// The kernel's kind and filter commands, then the list's own three.
    static let filterSpecs: [CommandSpec<HaloProject>] =
        AdjustCommands.specs(HaloProject.self).filter { !$0.id.hasPrefix("look.") } + listSpecs

    static let listSpecs: [CommandSpec<HaloProject>] = {
        let key = ParamSchema.string("The entry's key.", oneOf: HaloLayerFilter.ids)
        let ready: @Sendable (HaloProject) -> Availability = { $0.adjustHelp.map(Availability.unavailable) ?? .available }
        let done = JSONValue.object([:])
        return [
            .typed("filter.set-hidden", title: "Hide Filter", summary: "Hides or shows one of the selected layer's filters.",
                   kind: .edit, params: FilterHidden.self, schema: .object(["id": key, "hidden": .boolean], required: ["id", "hidden"]),
                   example: .object(["id": .string("gaussian-blur"), "hidden": .bool(true)]), availability: ready
            ) { p, o in try p.setLayerFilterHidden(o.id, o.hidden); return done },
            .typed("filter.remove", title: "Remove Filter", summary: "Removes one of the selected layer's filters.",
                   kind: .edit, params: FilterID.self, schema: .object(["id": key], required: ["id"]),
                   example: .object(["id": .string("gaussian-blur")]), availability: ready
            ) { p, o in try p.removeLayerFilter(o.id); return done },
            .typed("filter.move", title: "Move Filter", summary: "Moves one of the selected layer's filters in its list, 0 runs first.",
                   kind: .edit, params: FilterMove.self,
                   schema: .object(["id": key, "index": .integer(minimum: 0)], required: ["id", "index"]),
                   example: .object(["id": .string("gaussian-blur"), "index": .number(0)]), availability: ready
            ) { p, o in try p.moveLayerFilter(o.id, to: o.index); return done },
        ]
    }()
}
