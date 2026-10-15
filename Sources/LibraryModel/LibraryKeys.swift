// LibraryKeys.swift: Library's single keys and the `library.controls` JSON.
// `LibraryKey` names what a key press asks for; the window's `onKeyPress`
// hands it to the area that owns it (cull, view, photo). `controlsJSON` is
// the value J11 reads: every `library.*` control with whether it is enabled
// and, when not, why; the same shape as SuiteUI's `suite.controls`
// (`{"controls": [...]}`, sorted by id, sorted keys). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What a single key press asks of the grid or the loupe.
public enum LibraryKey: Hashable, Sendable {
    case rating(Int)  // 0...5
    case pick, reject, unflag
    case crop, grid
    case confirm  // Return
    case first, last  // Home, End

    /// "0"..."5" rate; P pick, X reject, U unflag, R crop, G grid, in
    /// either case. Anything else is nil (the key is ignored).
    public init?(character: Character) {
        if let digit = character.wholeNumberValue, character.isASCII, (0...5).contains(digit) {
            self = .rating(digit)
            return
        }
        switch character.lowercased() {
        case "p": self = .pick
        case "x": self = .reject
        case "u": self = .unflag
        case "r": self = .crop
        case "g": self = .grid
        default: return nil
        }
    }

    /// Return confirms, Home and End go to the first and last photo.
    public init(special: LibrarySpecialKey) {
        switch special {
        case .returnKey: self = .confirm
        case .home: self = .first
        case .end: self = .last
        }
    }
}

/// The non-character keys Library handles; the app maps its key events to these.
public enum LibrarySpecialKey: Hashable, Sendable {
    case returnKey, home, end
}

/// One `library.*` control: whether it acts, and why not when it can't.
public struct LibraryControlState: Hashable, Sendable, Codable {
    public var id: String
    public var enabled: Bool
    public var reason: String?
    public init(id: String, enabled: Bool, reason: String? = nil) {
        self.id = id; self.enabled = enabled; self.reason = reason
    }
}

/// The `library.controls` value: `{"controls": [...]}`, one entry per id
/// (the last given), sorted by id; `{}` if it can't encode.
public func controlsJSON(_ controls: [LibraryControlState]) -> String {
    struct Document: Encodable { var controls: [LibraryControlState] }
    var latest: [String: LibraryControlState] = [:]
    for control in controls { latest[control.id] = control }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let document = Document(controls: latest.values.sorted { $0.id < $1.id })
    guard let data = try? encoder.encode(document) else { return "{}" }
    return String(decoding: data, as: UTF8.self)
}
