// PhotoTextColor.swift (#5951): `text.set-color`, the selected text layer's colour. The kernel's seven text
// commands set face, size and paragraph but no colour, so `text.read` always said black; this one sets the
// style's `rgba` and redraws the words through `setTextStyle`, one undo step "Text Color" per drag. Linux-safe.
import SuiteKernel
import SuiteModel

extension PhotoWorkspace {
    /// text.set-color's: red, green, blue and alpha, each 0 to 255, and a drag's token.
    public struct TextColorParams: Codable, Sendable { public var rgba: [Int]; public var drag: String? }

    /// Sets every selected text layer's colour to `rgba`; one step "Text Color", steps under one `drag` fold.
    public mutating func setTextColor(_ rgba: [UInt8], drag: String? = nil) throws {
        guard var style = textStyle else { throw CatalogError.unavailable(id: "text.set-color", why: "Select a text layer first.") }
        guard rgba.count == 4 else { throw CatalogError.failed(id: "text.set-color", message: "A colour is four values, 0 to 255.") }
        style.rgba = rgba
        try setTextStyle(style, name: "Text Color", drag: drag)
    }

    /// The `text.set-color` command; `textCommands` lists it.
    static var textColorCommand: CommandSpec<PhotoWorkspace> {
        .typed("text.set-color", title: "Text Color", summary: "Sets the selected text layer's colour as red, green, blue and alpha, 0 to 255; one drag is one undo step.",
               kind: .edit, params: TextColorParams.self,
               schema: .object(["rgba": .array(of: .integer("0 to 255.", minimum: 0, maximum: 255), minItems: 4, maxItems: 4),
                                "drag": .optional(.string("A drag's token; edits under one token are one undo step.", maxLength: 64))],
                               required: ["rgba", "drag"]),
               example: .object(["rgba": .array([200, 30, 30, 255].map(JSONValue.number))]),
               availability: { $0.canvas == nil ? .unavailable("Open an image first.") : $0.textStyle == nil ? .unavailable("Select a text layer first.") : .available }
        ) { w, p -> TextStyle? in
            // The schema refuses values outside 0 to 255 before this runs.
            try w.setTextColor(p.rgba.map { UInt8(clamping: $0) }, drag: p.drag)
            return w.textStyle
        }
    }
}
