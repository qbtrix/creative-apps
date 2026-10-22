// FrameRateHomeTests.swift (frame-rates FR-11): the rate list lives once, in the kernel's `FrameRate.common`.
// Halo's `CompositionSettings.frameRates` and Flare's `NewDocumentSpec.frameRates` were two copies of it (FR-8 and
// FR-10 deleted them); this suite fails when a Model or App file under `Sources/` keeps its own list again, as a
// `...rates` declaration set to an array literal or as an array literal of three or more numbers that are all common rates.
// Comments and string literals are skipped, so a rate named in a doc comment or a label is no list. Files are read
// by path from #filePath.
import Foundation
import Testing

/// Finds frame-rate list literals in Swift source text.
enum FrameRateListScan {
    /// The common rates as written in source, whole and decimal.
    static let rateWords: Set<String> = ["12", "23.976", "24", "25", "29.97", "30", "50", "59.94", "60"]

    /// The 1-based lines of `text` that hold a rate list literal.
    static func lines(in text: String) -> [Int] {
        text.components(separatedBy: "\n").enumerated().compactMap { index, line in
            isList(code(line)) ? index + 1 : nil
        }
    }

    /// `line` without its string literals and its `//` comment.
    static func code(_ line: String) -> String {
        var out = "", inString = false, previous: Character = " "
        for char in line {
            if inString {
                if char == "\"" && previous != "\\" { inString = false }
            } else if char == "\"" {
                inString = true
            } else if char == "/" && previous == "/" {
                out.removeLast()
                break
            } else {
                out.append(char)
            }
            previous = char
        }
        return out
    }

    static func isList(_ code: String) -> Bool {
        if code.range(of: #"\b(let|var)\s+\w*[Rr]ates\b[^=]*=\s*\["#, options: .regularExpression) != nil { return true }
        guard let open = code.firstIndex(of: "[") else { return false }
        let words = code[open...].split(whereSeparator: { !$0.isNumber && $0 != "." }).map(String.init)
        return words.count >= 3 && words.allSatisfy(rateWords.contains)
    }
}

@Suite struct FrameRateHomeTests {
    static let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources")

    /// No Model or App target keeps a rate list (mutation: an app list survives).
    @Test func noAppKeepsARateList() throws {
        let folders = try FileManager.default.contentsOfDirectory(atPath: Self.sources.path)
            .filter { $0.hasSuffix("Model") || $0.hasSuffix("App") }
        #expect(folders.contains("HaloModel") && folders.contains("FlareModel"))
        var found: [String] = []
        for folder in folders.sorted() {
            let root = Self.sources.appendingPathComponent(folder)
            let files = FileManager.default.enumerator(atPath: root.path)?.compactMap { $0 as? String } ?? []
            for file in files.sorted() where file.hasSuffix(".swift") {
                let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
                found += FrameRateListScan.lines(in: text).map { "\(folder)/\(file):\($0)" }
            }
        }
        #expect(found.isEmpty, "keep rates in FrameRate.common: \(found)")
    }

    /// The scan finds both shapes of list and skips comments, labels and lone rates.
    @Test func scanFindsListsOnly() {
        #expect(FrameRateListScan.lines(in: "public static let frameRates: [Double] = [24, 25, 30]") == [1])
        #expect(FrameRateListScan.lines(in: "let x = 1\nlet choices = [23.976, 24, 29.97]") == [2])
        #expect(FrameRateListScan.lines(in: "static var rates = [FrameRate]()") == [1])
        #expect(FrameRateListScan.lines(in: "// rates: [24, 25, 30]\nlet label = \"[24, 25, 30] fps\"").isEmpty)
        #expect(FrameRateListScan.lines(in: "let size = [24, 48]\nlet fps = 24 // 23.976, 29.97, 59.94").isEmpty)
        #expect(FrameRateListScan.lines(in: "let ring = [(90, 50), (50, 90), (10, 50), (30, 60)]").isEmpty, "points, not rates")
    }
}
