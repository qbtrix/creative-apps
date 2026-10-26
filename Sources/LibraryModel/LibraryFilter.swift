// LibraryFilter.swift: the filter bar's rules, as plain values. A photo is
// shown when it passes every rule that is on: a flag in `flags` (empty: any
// flag), a rating the `rating` rule admits, a label in `labels` (empty: any
// label or none), and not rejected while `hidesRejected` is on. `summary`
// is what the bar and VoiceOver read, for example "At least 3 stars, Rejects
// hidden". A folder rule (`folder`, folders FO-5) shows one folder's photos,
// with or without its subfolders'. Linux-safe.

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
    /// The folder whose photos show (FolderScope in LibraryFolders+Kernel.swift); nil: any folder.
    public var folder: FolderScope?

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
        if let folder, !folder.admits(photo) { return false }
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
        if let folder { parts.append(folder.summaryPhrase) }
        return parts.joined(separator: ", ")
    }

    /// "A", "A or B", "A, B or C".
    private static func orList(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " or " + names[names.count - 1]
    }

    /// Why the bar can't act yet; nil since FC-7 built it.
    public static let unavailable: String? = nil
}

extension LibraryCatalog {
    /// The selected smart collection's rules, else the bar's `filter`.
    public var activeFilter: LibraryFilter {
        if case .rules(let rules) = selectedUserCollection?.contents { return rules }
        return filter
    }

    /// "<summary>; <shown> of <in the collection>".
    public var filterValue: String {
        activeFilter.summary + "; \(order.count) of \(collectionItems.count)"
    }

    /// "Rules of <name>" while a smart collection is selected.
    public var filterCaption: String? {
        guard let collection = selectedUserCollection, collection.isSmart else { return nil }
        return "Rules of \(collection.name)"
    }

    /// A collection that isn't smart has photos, and the filter shows none.
    public var isHiddenByFilter: Bool {
        selectedUserCollection?.isSmart != true && order.isEmpty && !collectionItems.isEmpty
    }

    public var filterHelp: String? {
        LibraryFilter.unavailable ?? (items.isEmpty ? "Import or load photos to filter them." : nil)
    }

    public var clearFilterHelp: String? {
        filterHelp ?? (activeFilter.isActive ? nil : "No filter is on.")
    }

    /// Why New Smart Collection from Filter can't run: it needs photos, a
    /// filter on, and no smart collection selected (the bar edits its rules).
    public var newSmartCollectionHelp: String? {
        if let unavailable = UserCollection.smartUnavailable ?? filterHelp { return unavailable }
        if selectedUserCollection?.isSmart == true {
            return "The filter bar edits this smart collection's rules. Select another collection first."
        }
        return filter.isActive ? nil : "Set a filter first: a smart collection keeps the filter's rules."
    }

    /// Sets the bar's filter and refreshes what is shown: the selection
    /// keeps the photos still shown, and a loupe on a hidden photo goes back
    /// to the grid. View state like the sort: no undo step, but the
    /// collections file is dirty. While a smart collection is selected the
    /// bar edits its rules instead, as one "Edit Rules" step, and `filter`
    /// stays as it was.
    public mutating func setFilter(_ filter: LibraryFilter) {
        guard filterHelp == nil else { return }
        if let smart = selectedUserCollection, smart.isSmart {
            recordCollectionsEdit("Edit Rules") { collections in
                guard let index = collections.firstIndex(where: { $0.id == smart.id }) else { return }
                collections[index].contents = .rules(filter)
            }
            return
        }
        self.filter = filter
        collectionsRevision += 1
        refreshShown()
    }

    /// Turns a flag chip on or off. Turning Rejected on turns Hide Rejected
    /// off, so the filter can always match something.
    public mutating func toggleFilterFlag(_ flag: PhotoFlag) {
        var next = activeFilter
        if next.flags.remove(flag) == nil {
            next.flags.insert(flag)
            if flag == .reject { next.hidesRejected = false }
        }
        setFilter(next)
    }

    /// Sets the rating rule; at least 0 stars is any rating.
    public mutating func setRatingRule(_ rule: RatingRule) {
        var next = activeFilter
        if case .atLeast(let minimum) = rule, minimum <= 0 {
            next.rating = .any
        } else {
            next.rating = rule
        }
        setFilter(next)
    }

    public mutating func toggleFilterLabel(_ label: PhotoLabel) {
        var next = activeFilter
        next.labels.formSymmetricDifference([label])
        setFilter(next)
    }

    /// Turns Hide Rejected on or off. Turning it on drops the Rejected chip.
    public mutating func toggleHideRejected() {
        var next = activeFilter
        next.hidesRejected.toggle()
        if next.hidesRejected { next.flags.remove(.reject) }
        setFilter(next)
    }

    public mutating func clearFilter() {
        guard clearFilterHelp == nil else { return }
        setFilter(.all)
    }

    /// Saves the bar's filter as a smart collection named by its summary,
    /// as one "New Smart Collection" step, and selects it; `filter` stays as
    /// it was. Returns its id, or nil when `newSmartCollectionHelp` says why not.
    @discardableResult public mutating func newSmartCollection() -> String? {
        guard newSmartCollectionHelp == nil else { return nil }
        let taken = userCollections.map(\.id).filter { $0.hasPrefix("smart-") }.compactMap { Int($0.dropFirst(6)) }
        let id = "smart-\((taken.max() ?? 0) + 1)"
        let rules = filter
        recordCollectionsEdit("New Smart Collection") { collections in
            collections.append(UserCollection(id: id, name: rules.summary, contents: .rules(rules)))
        }
        selectCollection(id)
        return id
    }
}
