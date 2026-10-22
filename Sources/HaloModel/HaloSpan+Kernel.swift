// HaloSpan+Kernel.swift (timeline-keys TK-2 stubs, TK-6 bodies): sliding and
// trimming a layer's bar as catalog commands. `layer.slide` moves the layer's
// in, out and every key by one delta clamped to the composition, through the
// kernel's `SpanRules.slide`; `layer.trim` moves one edge and leaves the keys.
// Each is one undo step, and runs under one `drag` token fold into one. The
// specs are declared here and join `commandSpecs` in TK-6; until then they
// are off with the reason, and a run says it is not built. Linux-safe.
import SuiteKernel

extension HaloProject {
    /// `layer.slide`'s params: the layer, the frames to slide by, and the drag
    /// token that folds a drag's runs into one step.
    public struct SlideParams: Codable, Sendable, Hashable {
        public var layer: String
        public var by: Int
        public var drag: String?
        public init(layer: String, by: Int, drag: String? = nil) { (self.layer, self.by, self.drag) = (layer, by, drag) }
    }

    /// `layer.trim`'s params: the layer, the edge ("start" or "end"), the
    /// frame the edge lands on, and the drag token.
    public struct TrimParams: Codable, Sendable, Hashable {
        public var layer: String
        public var edge: String
        public var frame: Int
        public var drag: String?
        public init(layer: String, edge: String, frame: Int, drag: String? = nil) {
            (self.layer, self.edge, self.frame, self.drag) = (layer, edge, frame, drag)
        }
    }

    /// Why slide and trim are off until TK-6 builds them.
    static let spanNotBuilt = "Slide and trim arrive with TK-6."

    /// The slide and trim specs, in menu order.
    public static var spanCommands: [CommandSpec<HaloProject>] {
        let layer = ParamSchema.string("The layer's id.", maxLength: 64)
        let drag = ParamSchema.optional(.string("A token shared by one drag's runs: one undo step.", maxLength: 64))
        return [
            .typed("layer.slide", title: "Slide Layer",
                   summary: "Slides a layer's bar and all its keys by a number of frames, kept inside the composition.",
                   kind: .edit, params: SlideParams.self,
                   schema: .object(["layer": layer, "by": .integer("Frames to slide; negative is earlier."), "drag": drag],
                                   required: ["layer", "by"]),
                   result: .object(["delta": .integer("The frames the layer moved after clamping.")], required: ["delta"]),
                   example: .object(["layer": .string("comp-1-layer-1"), "by": .number(6)]),
                   availability: { $0.spanAvailability }) { _, _ throws -> JSONValue in
                throw CatalogError.notBuilt(id: "layer.slide", feature: "timeline-keys TK-6")
            },
            .typed("layer.trim", title: "Trim Layer",
                   summary: "Moves a layer's start or end to a frame, leaving its keys where they are.",
                   kind: .edit, params: TrimParams.self,
                   schema: .object(["layer": layer, "edge": .string("The edge to move.", oneOf: ["start", "end"]),
                                    "frame": .integer("The frame the edge lands on.", minimum: 0), "drag": drag],
                                   required: ["layer", "edge", "frame"]),
                   result: .object(["in": .integer(), "out": .integer()], required: ["in", "out"]),
                   example: .object(["layer": .string("comp-1-layer-1"), "edge": .string("end"), "frame": .number(23)]),
                   availability: { $0.spanAvailability }) { _, _ throws -> JSONValue in
                throw CatalogError.notBuilt(id: "layer.trim", feature: "timeline-keys TK-6")
            },
        ]
    }

    /// Off without a composition or a layer; otherwise off until TK-6.
    var spanAvailability: Availability {
        guard let comp = selectedComposition else { return .unavailable("Open a composition to slide or trim a layer.") }
        guard !comp.layers.isEmpty else { return .unavailable("Add a layer to slide or trim it.") }
        return .unavailable(Self.spanNotBuilt)
    }
}
