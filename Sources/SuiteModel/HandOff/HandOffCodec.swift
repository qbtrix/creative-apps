// HandOffCodec.swift: the `.aghandoff` file format. Sorted-key JSON; a
// newer format is refused by name, an id that could name a nested path is
// damaged, and a failed encode is a failed save. Foundation only for JSON, Linux-safe.
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
        do { return try e.encode(h) } catch { throw encodeFailure }
    }

    public static func decode(_ data: Data) throws(SuiteError) -> HandOff {
        struct Head: Decodable { var format: Int }
        guard let head = try? JSONDecoder().decode(Head.self, from: data) else { throw .damaged(subject) }
        guard head.format <= HandOff.formatVersion else {
            throw .notAvailable("This was sent by a newer AfterGlow. Update AfterGlow to open it.")
        }
        let h: HandOff
        do { h = try JSONDecoder().decode(HandOff.self, from: data) } catch { throw .damaged(subject) }
        guard isSafeID(h.id) else { throw .damaged(subject) }
        return h
    }

    /// What `encode` throws when it can't write: a failed save, never a damaged file.
    public static let encodeFailure = SuiteError.ioFailed(subject)

    /// What a damaged hand-off is called in the message the user sees.
    static let subject = "the message from another app"

    /// An id names `handoffs/<id>.aghandoff`, so it holds only a-z, 0-9 and -.
    static func isSafeID(_ id: String) -> Bool {
        !id.isEmpty && id.unicodeScalars.allSatisfy { s in
            ("a"..."z").contains(s) || ("0"..."9").contains(s) || s == "-"
        }
    }
}
