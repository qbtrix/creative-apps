// LibraryFilter.swift: the filter bar's rules, as plain values. A photo is
// shown when it passes every rule that is on: a flag in `flags` (empty: any
// flag), a rating the `rating` rule admits, a label in `labels` (empty: any
// label or none), and not rejected while `hidesRejected` is on. `summary`
// is what the bar and VoiceOver read, for example "At least 3 stars, Rejects
// hidden". Linux-safe.

/// How many stars a photo needs: any, at least N, or exactly N. Exactly 0
/// is unrated.
public enum RatingRule: Hashable, Sendable {
    case any, atLeast(Int), exactly(Int)

    /// Whether a photo with `stars` stars passes this rule.
    public func admits(_ stars: Int) -> Bool {
        switch self {
        case .any: true
        case .atLeast(let minimum): stars >= minimum
        case .exactly(let count): stars == count
        }
    }

    /// The rule's menu title: "Any Rating", "At Least 3 Stars", "Exactly 1 Star", "Unrated".
    public var title: String {
        switch self {
        case .any: "Any Rating"
        case .atLeast(let count): "At Least \(count) \(count == 1 ? "Star" : "Stars")"
        case .exactly(0): "Unrated"
        case .exactly(let count): "Exactly \(count) \(count == 1 ? "Star" : "Stars")"
        }
    }

    /// The rule as a phrase in the bar's summary, nil for any rating.
    var summaryPhrase: String? {
        switch self {
        case .any: nil
        case .atLeast(let count): "At least \(count) \(count == 1 ? "star" : "stars")"
        case .exactly(0): "Unrated"
        case .exactly(let count): "Exactly \(count) \(count == 1 ? "star" : "stars")"
        }
    }
}

/// The filter bar's state: which flags, ratings and labels to show, and
/// whether rejected photos are hidden.
public struct LibraryFilter: Hashable, Sendable {
    public var flags: Set<PhotoFlag> = []
    public var rating = RatingRule.any
    public var labels: Set<PhotoLabel> = []
    public var hidesRejected = false

    /// No rule on: every photo shows.
    public static let all = LibraryFilter()

    /// Whether any rule is on.
    public var isActive: Bool { self != .all }

    /// Whether `photo` passes every rule that is on.
    public func matches(_ photo: PhotoItem) -> Bool {
        if !flags.isEmpty, !flags.contains(photo.flag) { return false }
        if !rating.admits(photo.rating) { return false }
        if !labels.isEmpty {
            guard let label = photo.label, labels.contains(label) else { return false }
        }
        if hidesRejected, photo.flag == .reject { return false }
        return true
    }

    /// "All photos" when no rule is on. Else the flags ("Picked or
    /// Unflagged"), the rating ("At least 3 stars"), the labels ("Red or
    /// Blue") and "Rejects hidden", joined by ", ".
    public var summary: String {
        guard isActive else { return "All photos" }
        var parts: [String] = []
        let flagOrder: [PhotoFlag] = [.pick, .none, .reject]
        let flagNames: [PhotoFlag: String] = [.pick: "Picked", .none: "Unflagged", .reject: "Rejected"]
        let flagList = flagOrder.filter(flags.contains).compactMap { flagNames[$0] }
        if !flagList.isEmpty { parts.append(Self.orList(flagList)) }
        if let phrase = rating.summaryPhrase { parts.append(phrase) }
        let labelList = PhotoLabel.allCases.filter(labels.contains).map(\.rawValue)
        if !labelList.isEmpty { parts.append(Self.orList(labelList)) }
        if hidesRejected { parts.append("Rejects hidden") }
        return parts.joined(separator: ", ")
    }

    /// "A", "A or B", "A, B or C".
    private static func orList(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " or " + names[names.count - 1]
    }
}
