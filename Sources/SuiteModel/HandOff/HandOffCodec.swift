// HandOffCodec.swift: the `.aghandoff` file format. Sorted-key JSON; a
// newer format is refused by name, and an id that could name a nested path
// is damaged. Foundation only for JSON, Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The `.aghandoff` file format: sorted-key JSON; a newer format is refused by name.
public enum HandOffCodec {
    public static func encode(_ h: HandOff) throws(SuiteError) -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        do { return try e.encode(h) } catch { throw .damaged("hand-off could not be written") }
    }

    public static func decode(_ data: Data) throws(SuiteError) -> HandOff {
        struct Head: Decodable { var format: Int }
        guard let head = try? JSONDecoder().decode(Head.self, from: data) else { throw .damaged("not a hand-off") }
        guard head.format <= HandOff.formatVersion else {
            throw .notAvailable("This was sent by a newer AfterGlow. Update AfterGlow to open it.")
        }
        let h: HandOff
        do { h = try JSONDecoder().decode(HandOff.self, from: data) } catch { throw .damaged("hand-off fields") }
        guard isSafeID(h.id) else { throw .damaged("hand-off id") }
        return h
    }

    /// An id names `handoffs/<id>.aghandoff`, so it holds only a-z, 0-9 and -.
    static func isSafeID(_ id: String) -> Bool {
        !id.isEmpty && id.unicodeScalars.allSatisfy { s in
            ("a"..."z").contains(s) || ("0"..."9").contains(s) || s == "-"
        }
    }
}
