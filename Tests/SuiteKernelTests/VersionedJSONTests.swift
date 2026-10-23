// VersionedJSONTests.swift: the version probe's checks (editor-kernel EK-23, slice EK-doc).
// `probe` reads the integer version at the top of a JSON object before the
// document is decoded, says `missing` when the key is absent, `damaged` when
// the bytes are not a JSON object and `newer` when the file is newer than this
// app reads; `words` puts a decoding error in words that name the coding path.
// Written first (EK-23) and turned on by EK-24 (docs/factory/lead.md rule 13).
import Foundation
import Testing
import SuiteKernel

@Suite struct VersionedJSONTests {
    static func json(_ text: String) -> Data { Data(text.utf8) }

    @Test func probeReadsTheVersion() throws {
        #expect(try VersionedJSON.probe(Self.json(#"{"version": 2, "layers": []}"#)) == 2)
        #expect(try VersionedJSON.probe(Self.json(#"{"layers": [], "version": 5}"#)) == 5)
        #expect(try VersionedJSON.probe(Self.json(#"{"format": 3}"#), key: "format") == 3)
    }

    @Test func probeNamesTheMissingKey() {
        #expect(throws: VersionError.missing("version")) {
            try VersionedJSON.probe(Self.json(#"{"layers": []}"#))
        }
        #expect(throws: VersionError.missing("format")) {
            try VersionedJSON.probe(Self.json(#"{"version": 1}"#), key: "format")
        }
        // Only the top level counts: a nested version is not the file's.
        #expect(throws: VersionError.missing("version")) {
            try VersionedJSON.probe(Self.json(#"{"meta": {"version": 1}}"#))
        }
    }

    @Test func probeRefusesDamaged() {
        for text in ["", "not json", "[1, 2]", #"{"version": 2"#, "42"] {
            #expect(throws: VersionError.damaged) { try VersionedJSON.probe(Self.json(text)) }
        }
        #expect(throws: VersionError.damaged) { try VersionedJSON.probe(Data([0xFF, 0xFE, 0x00])) }
    }

    /// A version that is not an integer is not a version the probe can read.
    @Test func probeRefusesNonIntegerVersion() {
        #expect(throws: VersionError.self) { try VersionedJSON.probe(Self.json(#"{"version": "two"}"#)) }
        #expect(throws: VersionError.self) { try VersionedJSON.probe(Self.json(#"{"version": 1.5}"#)) }
    }

    /// A file newer than the app reads is refused with both versions, so the
    /// alert can say which app version to update to; the same version or an
    /// older one reads.
    @Test func refusesNewer() throws {
        #expect(throws: VersionError.newer(found: 3, supported: 2)) {
            try VersionedJSON.probe(Self.json(#"{"version": 3}"#), supported: 2)
        }
        #expect(try VersionedJSON.probe(Self.json(#"{"version": 2}"#), supported: 2) == 2)
        #expect(try VersionedJSON.probe(Self.json(#"{"version": 1}"#), supported: 2) == 1)
        #expect(throws: VersionError.missing("format")) {
            try VersionedJSON.probe(Self.json(#"{"version": 1}"#), key: "format", supported: 2)
        }
        #expect(VersionError.newer(found: 3, supported: 2) != .newer(found: 2, supported: 3))
    }

    struct Layer: Decodable { var name: String; var opacity: Double }
    struct Doc: Decodable { var version: Int; var layers: [Layer] }

    /// The words name where in the file the decoding stopped.
    @Test func wordsNameThePath() {
        let text = #"{"version": 1, "layers": [{"name": "Sky", "opacity": 1}, {"name": "Sea"}]}"#
        do {
            _ = try JSONDecoder().decode(Doc.self, from: Self.json(text))
            Issue.record("decoding a layer with no opacity should fail")
        } catch let error as DecodingError {
            let words = VersionedJSON.words(for: error)
            #expect(words.contains("layers"))
            #expect(words.contains("opacity"))
            #expect(words != "The file could not be read.")
        } catch {
            Issue.record("expected a DecodingError, got \(error)")
        }
    }

    @Test func wordsDifferByError() {
        let wrongKind = #"{"version": 1, "layers": [{"name": 4, "opacity": 1}]}"#
        let missing = #"{"version": 1}"#
        let texts = [wrongKind, missing].map { text -> String in
            do {
                _ = try JSONDecoder().decode(Doc.self, from: Self.json(text))
                return ""
            } catch let error as DecodingError {
                return VersionedJSON.words(for: error)
            } catch {
                return ""
            }
        }
        #expect(texts.allSatisfy { !$0.isEmpty })
        #expect(Set(texts).count == 2)
        #expect(texts.last?.contains("layers") == true)
    }
}
