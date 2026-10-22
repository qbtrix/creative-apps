// PhotoTextEdit.swift (text-layers TX-4): editing a text layer's words. A Type tool click on a visible text
// layer (so a double-click) opens the box over it holding its words and selects it; the box's commit runs
// `text.set-words`, one "Edit Text" step, and adds nothing when the words didn't change. Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace {
    /// The topmost visible text layer whose pixels cover `point`; nil when none does.
    func textLayer(at point: Mask.Point) -> PhotoLayer.ID? {
        layers.first { layer in
            guard layer.isVisible, case .text = layer.kind, let drawn = pixels[layer.id] else { return false }
            let x = point.x - Double(layer.offsetX), y = point.y - Double(layer.offsetY)
            return x >= 0 && y >= 0 && x < Double(drawn.width) && y < Double(drawn.height)
        }?.id
    }

    /// Selects text layer `id` and opens a box over it holding its words; nothing for a layer that isn't text.
    mutating func editText(_ id: PhotoLayer.ID) {
        guard let at = index(of: id), case .text(let text) = layers[at].kind else { return }
        selectedLayerID = id
        textBox = PhotoTextBox(origin: text.origin, draft: text.words, editing: id)
    }

    /// Runs `text.set-words` on layer `id` with `words`; unchanged words add no step, a refusal says why.
    mutating func commitEdit(of id: PhotoLayer.ID, words: String) {
        guard let at = index(of: id), case .text(let text) = layers[at].kind, text.words != words else { return }
        selectedLayerID = id
        do {
            _ = try Self.catalog.run("text.set-words", params: .object(["words": .string(words)]), on: &self)
        } catch {
            statusMessage = textHelp ?? (words.isEmpty ? "Type some words first." : "Couldn't edit the text.")
        }
    }
}
