// PhotoTextBox.swift (text-layers TX-3): the Type tool's box on the canvas. A click with the Type tool
// opens one at the press (`endDrag`); the view's field sends what is typed to `typeText`, Esc to
// `cancelTextBox` and Return or focus loss to `commitTextBox`, which runs `text.add` with the draft. Another
// click or another tool commits the open box first. The box is the draft only: nothing in the document
// changes until the commit; a refused commit says why in the status line.
// Linux-safe.
import CoreRaster
import SuiteKernel

/// An open Type tool box: where its top-left sits in canvas pixels and the words typed so far.
public struct PhotoTextBox: Hashable, Sendable {
    public var origin: Mask.Point
    public var draft: String

    public init(origin: Mask.Point, draft: String) {
        self.origin = origin
        self.draft = draft
    }
}

extension PhotoWorkspace {
    /// Opens an empty box at `origin`, committing any open one first.
    mutating func openTextBox(at origin: Mask.Point) {
        commitTextBox()
        textBox = PhotoTextBox(origin: origin, draft: "")
    }

    /// The open box's words become `words`; nothing without a box.
    public mutating func typeText(_ words: String) {
        textBox?.draft = words
    }

    /// Closes the open box and drops its words.
    public mutating func cancelTextBox() {
        textBox = nil
    }

    /// Closes the open box and adds its words as a text layer at its origin in one step. An empty box just
    /// closes; a refusal leaves the document as it was and puts the reason in the status line.
    public mutating func commitTextBox() {
        guard let box = textBox else { return }
        textBox = nil
        guard !box.draft.isEmpty, let canvas else { return }
        let x = Self.pixel(box.origin.x, below: canvas.width), y = Self.pixel(box.origin.y, below: canvas.height)
        let params = JSONValue.object(["x": .number(Double(x)), "y": .number(Double(y)), "words": .string(box.draft)])
        do {
            _ = try Self.catalog.run("text.add", params: params, on: &self)
        } catch {
            statusMessage = textHelp ?? "Couldn't add the text."
        }
    }

    /// `value` rounded to a whole pixel in 0..<limit; 0 when it isn't a number.
    private static func pixel(_ value: Double, below limit: Int) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(max(value.rounded(), 0), Double(max(limit - 1, 0))))
    }
}
