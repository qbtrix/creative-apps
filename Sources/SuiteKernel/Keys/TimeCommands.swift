// TimeCommands.swift (frame-rates FR-1 specs with real ids and schemas, FR-3 bodies): `time.rates` and
// `time.timecode`, the queries every timed app registers with one line, `+ TimeCommands.specs(<X>Workspace.self)`.
// They read no document: the rate list and the timecode rule are the kernel's.

/// The kernel's time queries: the rate list and timecode conversion.
public enum TimeCommands {
    struct Empty: Codable, Sendable {}
    /// A rate as params carry it: `{num, den}`.
    struct Rate: Codable, Sendable { var num, den: Int }
    /// `time.timecode`'s params: a frame to label or a label to read, at a rate.
    struct TimecodeParams: Codable, Sendable { var frame: Int?; var text: String?; var rate: Rate }
    /// `time.timecode`'s result: the frame and its label; the frame is null for a label drop-frame skips.
    struct TimecodeResult: Codable, Sendable {
        var frame: Int?; var text: String
        /// Writes `frame` as null rather than leaving it out, so both keys the schema requires are always there.
        func encode(to encoder: Encoder) throws {
            var keyed = encoder.container(keyedBy: CodingKeys.self)
            try keyed.encode(frame, forKey: .frame)
            try keyed.encode(text, forKey: .text)
        }
    }

    /// `time.timecode`'s run: a frame becomes its label; else a label becomes its frame (null when skipped).
    static func timecode(_ p: TimecodeParams) -> TimecodeResult {
        let rate = FrameRate(numerator: p.rate.num, denominator: p.rate.den)
        if let frame = p.frame { return TimecodeResult(frame: frame, text: Timecode.string(frame: frame, rate: rate)) }
        let text = p.text ?? ""
        return TimecodeResult(frame: Timecode.frame(text, rate: rate), text: text)
    }
    /// `time.rates`' result entry.
    struct RateEntry: Codable, Sendable { var num, den: Int; var title: String; var dropFrame: Bool }

    static let rate = ParamSchema.object(
        ["num": .integer("Frames per `den` seconds: 30000 for 29.97.", minimum: 1),
         "den": .integer("The rate's denominator: 1 for a whole rate, 1001 for 29.97.", minimum: 1)],
        required: ["num", "den"])
    static let entry = ParamSchema.object(
        ["num": .integer(minimum: 1), "den": .integer(minimum: 1), "title": .string("\"29.97 fps\"."),
         "dropFrame": .boolean], required: ["num", "den", "title", "dropFrame"])

    /// The two time commands on any `target`; both are queries that read no document.
    public static func specs<T>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("time.rates", title: "Frame Rates", summary: "Lists the frame rates every timed app offers, slowest first, each as an exact fraction.",
                   kind: .query, params: Empty.self, schema: ParamSchema.none,
                   result: .object(["rates": .array(of: entry)], required: ["rates"]), example: .object([:])) { _, _ in
                       ["rates": FrameRate.common.map { RateEntry(num: $0.numerator, den: $0.denominator, title: $0.description, dropFrame: $0.isDropFrame) }]
                   },
            .typed("time.timecode", title: "Timecode", summary: "Converts a frame to its timecode at a rate, or a timecode back to its frame; drop-frame at 29.97 and 59.94.",
                   kind: .query, params: TimecodeParams.self,
                   schema: .object(["frame": .optional(.integer("The frame to label.", minimum: 0)),
                                    "text": .optional(.string("The timecode to read, HH:MM:SS:FF or HH:MM:SS;FF.")), "rate": rate],
                                   required: ["frame", "text", "rate"]),
                   result: .object(["frame": .optional(.integer(minimum: 0)), "text": .string()], required: ["frame", "text"]),
                   example: .object(["frame": .number(1800), "rate": .object(["num": .number(30000), "den": .number(1001)])])) { _, p in
                       timecode(p)
                   },
        ]
    }
}
