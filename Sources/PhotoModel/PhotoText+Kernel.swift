// PhotoText+Kernel.swift (text-layers TX-2 stubs; TX-5 bodies): Photo's text layers on the kernel's text
// commands. The workspace is a `TextStyleTarget` (the selected text layer's style), and `text.add` and
// `text.set-words` join the kernel's seven `TextCommands.specs` with their real ids, schemas and availability.
// Every run refuses with `textCommandsNotBuilt` until TX-5, which also appends `textCommands` to Photo's
// catalog. Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace: TextStyleTarget {
    /// text.add's: where the box's top-left goes in canvas pixels, the words, and a style (the standard one when nil).
    public struct TextAddParams: Codable, Sendable { public var x, y: Int; public var words: String; public var style: TextStyle? }
    /// text.set-words': the selected text layer's new words.
    public struct TextWordsParams: Codable, Sendable { public var words: String }

    /// What every text run throws until TX-5.
    static let textCommandsNotBuilt = CatalogError.notBuilt(id: "text", feature: "photo text-layers TX-5")
    /// What saving a document with a text layer throws until TX-6.
    static let textNotBuilt = CatalogError.notBuilt(id: "text", feature: "photo text-layers TX-6")

    public var textStyle: TextStyle? {
        guard case .text(let text) = selectedLayer?.kind else { return nil }
        return text.style
    }

    public var textHelp: String? { canvas == nil ? "Open an image first." : "Text arrives with TX-5." }

    public func faces(of family: String) -> [(weight: Int, italic: Bool)] { [] }

    public mutating func setTextStyle(_ s: TextStyle, name: String, drag: String?) throws { throw TextStyleRules.notBuilt }

    /// text.add, text.set-words and the kernel's seven text commands.
    static var textCommands: [CommandSpec<PhotoWorkspace>] {
        [
            .typed("text.add", title: "Add Text", summary: "Adds a text layer above the selected one, its box's top-left at x, y.",
                   kind: .edit, params: TextAddParams.self,
                   schema: .object(["x": .integer("Canvas pixels from the left."), "y": .integer("Canvas pixels from the top."),
                                    "words": .string("The words; a newline starts a paragraph.")], required: ["words", "x", "y"]),
                   example: .object(["x": .number(40), "y": .number(60), "words": .string("SALE")]),
                   availability: { $0.canvas == nil ? .unavailable("Open an image first.") : .available }
            ) { _, _ -> JSONValue in throw textCommandsNotBuilt },
            .typed("text.set-words", title: "Edit Text", summary: "Replaces the selected text layer's words and redraws it.",
                   kind: .edit, params: TextWordsParams.self,
                   schema: .object(["words": .string("The new words.")], required: ["words"]),
                   example: .object(["words": .string("SALE NOW")]), availability: { wordsAvailability($0) }
            ) { _, _ -> JSONValue in throw textCommandsNotBuilt },
        ] + TextCommands.specs(PhotoWorkspace.self)
    }

    /// text.set-words needs an open image and a selected text layer.
    private static func wordsAvailability(_ workspace: PhotoWorkspace) -> Availability {
        if workspace.canvas == nil { return .unavailable("Open an image first.") }
        return workspace.textStyle == nil ? .unavailable("Select a text layer first.") : .available
    }
}
