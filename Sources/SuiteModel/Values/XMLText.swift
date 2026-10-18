// XMLText.swift: the one XML escaping rule every export writer uses (Design's
// SVG, Photo's OpenRaster stack.xml). It lives in SuiteModel so no app keeps
// its own copy (docs/factory/lead.md, contract rule 20: one copy of a
// concept). The five entities are the predefined ones of XML 1.0 (W3C, 4.6).
// Stdlib only, Linux-safe.

/// One XML text and attribute escaper, shared by every app's export.
public enum XMLText {
    /// `text` safe inside an element or a single- or double-quoted attribute:
    /// & < > " ' become &amp; &lt; &gt; &quot; &apos;; everything else is unchanged.
    public static func escaped(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(character)
            }
        }
        return out
    }
}
