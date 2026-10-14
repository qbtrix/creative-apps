// MetadataEditing.swift: the inspector's view of the selected photos and the
// edits it makes to them: rating, flag and color label. Every edit applies
// to every selected photo; a field whose values differ reads as mixed. A
// rating outside 0...5 is refused. Keywords and camera details are #744.
// Linux-safe.

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

    /// Sets the selected photos' rating; a rating outside 0...5 is refused.
    public mutating func setRating(_ stars: Int) {
        guard (0...5).contains(stars) else { return }
        editSelected { $0.rating = stars }
    }

    /// A click on star `stars`: sets that rating, or clears it when every
    /// selected photo already has it.
    public mutating func clickStar(_ stars: Int) {
        setRating(selectedMetadata?.rating == .value(stars) ? 0 : stars)
    }

    public mutating func setFlag(_ flag: PhotoFlag) {
        editSelected { $0.flag = flag }
    }

    public mutating func setLabel(_ label: PhotoLabel?) {
        editSelected { $0.label = label }
    }
}
