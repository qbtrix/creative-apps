// XMLTextTests.swift: the one XML escaper in SuiteModel, and the guard that no
// app Model keeps a second copy of it (finding #2932, contract rule 20).
import Foundation
import SuiteModel
import Testing

@Suite struct XMLTextTests {
    @Test func escapesTheFivePredefinedEntities() {
        #expect(XMLText.escaped("a&b<c>\"d'") == "a&amp;b&lt;c&gt;&quot;d&apos;")
    }

    @Test func plainTextIsUnchanged() {
        #expect(XMLText.escaped("Layer 1 é") == "Layer 1 é")
        #expect(XMLText.escaped("") == "")
    }

    @Test func ampersandIsEscapedOnceNotTwice() {
        #expect(XMLText.escaped("&amp;") == "&amp;amp;")
    }

    @Test func unescapedReadsBackWhatEscapedWrote() {
        let text = "a&b<c>\"d'&lt;"
        #expect(XMLText.unescaped(XMLText.escaped(text)) == text)
        #expect(XMLText.unescaped("&amp;lt;") == "&lt;")
        #expect(XMLText.unescaped("Layer 1 &copy;") == "Layer 1 &copy;")
    }

    /// No Model other than SuiteModel writes the `&amp;` entity itself: they call XMLText.
    @Test func noAppModelKeepsItsOwnEscaper() throws {
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources")
        let fm = FileManager.default
        let models = try fm.contentsOfDirectory(atPath: sources.path)
            .filter { $0.hasSuffix("Model") && $0 != "SuiteModel" }
        #expect(!models.isEmpty)
        var offenders: [String] = []
        for model in models {
            let root = sources.appendingPathComponent(model)
            guard let walker = fm.enumerator(atPath: root.path) else { continue }
            for case let path as String in walker where path.hasSuffix(".swift") {
                let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
                if text.contains("\"&amp;\"") { offenders.append(model + "/" + path) }
            }
        }
        #expect(offenders == [])
    }
}
