// MetadataEditing.swift: the inspector's view of the selected photos and the
// edits it and the Metadata menu make: rating, flag and color label. Every
// edit goes through `cull(_:advance: false)`, so it changes the cull targets
// (the loupe photo in the loupe, else the selection) as the same named undo
// step a key makes, and never moves the loupe. A field whose values differ
// reads as mixed. A rating outside 0...5 is silently refused. Keywords and
// camera details are #744. Linux-safe.

/// A pick, a reject, or neither. The raw value is the menu title.
public enum PhotoFlag: String, CaseIterable, Sendable, Hashable {
    case none = "None", pick = "Pick", reject = "Reject"
}

/// One field across the selected photos: the value they share, or mixed.
public enum MetadataValue<Value: Hashable & Sendable>: Hashable, Sendable {
    case value(Value), mixed

    /// The shared value, or nil when mixed.
    public var shared: Value? {
        if case .value(let value) = self { value } else { nil }
    }

    /// Mixed unless every value is equal; `values` must not be empty.
    static func of(_ values: [Value]) -> MetadataValue? {
        guard let first = values.first else { return nil }
        return values.allSatisfy { $0 == first } ? .value(first) : .mixed
    }
}

/// What the inspector shows for the selected photos.
public struct PhotoMetadata: Sendable, Hashable {
    public static let mixedText = "Mixed"

    /// The photo's name, or "3 Photos".
    public let title: String
    public let rating: MetadataValue<Int>
    public let flag: MetadataValue<PhotoFlag>
    public let label: MetadataValue<PhotoLabel?>

    init?(_ photos: [PhotoItem]) {
        guard let rating = MetadataValue.of(photos.map(\.rating)), let flag = MetadataValue.of(photos.map(\.flag)),
              let label = MetadataValue.of(photos.map(\.label)), let first = photos.first
        else { return nil }
        title = photos.count == 1 ? first.name : "\(photos.count) Photos"
        self.rating = rating
        self.flag = flag
        self.label = label
    }
}

extension LibraryCatalog {
    /// The selected photos as the inspector shows them; nil with nothing selected.
    public var selectedMetadata: PhotoMetadata? {
        PhotoMetadata(sortedItems.filter { selection.contains($0.id) })
    }

    /// Sets the cull targets' rating as one "Set Rating" step; a rating
    /// outside 0...5 is refused without a `cullError`.
    public mutating func setRating(_ stars: Int) {
        guard (0...5).contains(stars) else { return }
        cull(.rating(stars), advance: false)
    }

    /// A click on star `stars`: sets that rating, or clears it when every
    /// cull target already has it.
    public mutating func clickStar(_ stars: Int) {
        let ids = cullTargets
        let current = PhotoMetadata(items.filter { ids.contains($0.id) })?.rating
        setRating(current == .value(stars) ? 0 : stars)
    }

    /// Flags the cull targets as one "Pick", "Reject" or "Clear Flag" step.
    public mutating func setFlag(_ flag: PhotoFlag) {
        cull(.flag(flag), advance: false)
    }

    /// Labels the cull targets as one "Set Label" step.
    public mutating func setLabel(_ label: PhotoLabel?) {
        cull(.label(label), advance: false)
    }
}
