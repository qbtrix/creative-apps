// PhotoTextLayer+ORA.swift (text-layers TX-6): a text layer in the `.ora`. LiveArchive writes its pixels as
// any layer's PNG, and its stack.xml <layer> gains `afterglow:text`, the PhotoTextLayer as JSON, so another
// OpenRaster reader shows the pixels and Photo reopens the words and style. On read only that attribute of
// stack.xml is looked at: a valid one makes the pixel layer with that `src` a text layer; a missing or
// damaged one leaves it pixels, never an error. Unknown JSON keys are ignored. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

extension PhotoTextLayer {
    /// The stack.xml attribute that holds a text layer's words and style.
    static let oraAttribute = "afterglow:text"

    /// The layer as the attribute's value: JSON with sorted keys, not yet escaped.
    func oraValue() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }

    /// Every readable `afterglow:text` in `stack`, keyed by its layer's `src`; empty without a stack.
    static func oraTexts(inStack stack: Data?) -> [String: PhotoTextLayer] {
        guard let stack else { return [:] }
        var texts: [String: PhotoTextLayer] = [:]
        for element in String(decoding: stack, as: UTF8.self).split(separator: "<layer ").dropFirst() {
            let tag = " " + element.prefix { $0 != ">" }
            guard let src = attribute("src", in: tag), let json = attribute(oraAttribute, in: tag),
                  let text = try? JSONDecoder().decode(PhotoTextLayer.self, from: Data(json.utf8)) else { continue }
            texts[src] = text
        }
        return texts
    }

    /// The unescaped value of ` name="…"` in `tag`; nil when the tag has none.
    private static func attribute(_ name: String, in tag: String) -> String? {
        guard let start = tag.firstRange(of: " \(name)=\"") else { return nil }
        return XMLText.unescaped(tag[start.upperBound...].prefix { $0 != "\"" })
    }
}

extension PhotoLayerKind {
    /// The words and style of a text layer; nil for any other kind.
    var textLayer: PhotoTextLayer? {
        if case .text(let text) = self { text } else { nil }
    }
}
