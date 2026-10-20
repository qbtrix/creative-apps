// LibraryKeywords.swift (metadata-more MD-10): keywords on the cull targets,
// the loupe photo in the loupe, else the selection. Typed text is split on
// commas, trimmed, its inner spaces collapsed and deduplicated without regard
// to case, and each name takes the catalog's existing spelling. Each gesture
// is one named undo step through `recordEdit` ("Add Keyword", "Add Keywords",
// "Remove Keyword"); one that changes nothing records none. `keywordStates`
// counts each keyword across the targets; suggestions rank the catalog's
// keywords the targets don't all have. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One keyword across the cull targets: on `count` of `total` photos.
public struct KeywordState: Hashable, Sendable {
    public let name: String
    public let count: Int
    public let total: Int

    public init(name: String, count: Int, total: Int) {
        self.name = name
        self.count = count
        self.total = total
    }

    /// On some targets but not all ("Beach 3 of 5"), drawn dimmer.
    public var isPartial: Bool { count < total }
}

extension LibraryCatalog {
    /// "Select a photo to add keywords." with no cull targets, else nil.
    public var keywordHelp: String? {
        cullTargets.isEmpty ? "Select a photo to add keywords." : nil
    }

    /// Each keyword on any cull target with how many have it, sorted without
    /// regard to case; spellings that differ only in case count as one.
    public var keywordStates: [KeywordState] {
        let targets = keywordTargets
        var states: [String: (name: String, count: Int)] = [:]
        for photo in targets {
            for key in Set(photo.keywords.map { $0.lowercased() }) {
                let name = states[key]?.name ?? photo.keywords.first { $0.lowercased() == key } ?? key
                states[key] = (name, (states[key]?.count ?? 0) + 1)
            }
        }
        return states.sorted { $0.key < $1.key }.map {
            KeywordState(name: $0.value.name, count: $0.value.count, total: targets.count)
        }
    }

    /// Adds the comma-separated keywords in `text` to the cull targets as one
    /// "Add Keyword" or "Add Keywords" step; none when every target has them.
    public mutating func addKeywords(_ text: String) {
        addKeywordNames(normalizedKeywords(text.split(separator: ",").map(String.init)))
    }

    /// Makes a partial keyword whole: adds `name` to every cull target as one
    /// "Add Keyword" step.
    public mutating func addKeyword(toAll name: String) {
        addKeywordNames(normalizedKeywords([name]))
    }

    /// Removes `name` (any case) from the cull targets as one "Remove Keyword" step.
    public mutating func removeKeyword(_ name: String) {
        let key = Self.collapsed(name).lowercased()
        let ids = cullTargets
        guard !ids.isEmpty, !key.isEmpty else { return }
        recordEdit("Remove Keyword", ids: ids) { photo in
            photo.keywords.removeAll { $0.lowercased() == key }
        }
    }

    /// The catalog's keywords for the add field, at most `limit`, leaving out
    /// those every target has. With a prefix: names with a word starting with
    /// it (any case), the whole name starting with it first, then those that
    /// keep the targets' keywords company most often, then the most used.
    /// With none: keywords of photos taken within an hour of a target first.
    public func keywordSuggestions(prefix: String, limit: Int = 8) -> [String] {
        guard limit > 0 else { return [] }
        let typed = Self.collapsed(prefix).lowercased()
        let targets = keywordTargets
        // One pass: each spelling gets a number, its lowercased form and
        // whether a target has it on first sight; a photo with one of the
        // targets' keywords then counts company for all of its own.
        let theirs = Set(targets.flatMap(\.keywords).map { $0.lowercased() })
        var number = SpellingNumbers()
        var spellings: [String] = [], lowered: [String] = [], isTheirs: [Bool] = []
        var uses: [Int] = [], company: [Int] = []
        var photoIDs: [Int] = []
        for index in items.indices {  // by index: no photo is copied
            photoIDs.removeAll(keepingCapacity: true)
            var withTheirs = false
            for keyword in items[index].keywords {
                let id = number.id(of: keyword, in: spellings)
                if id == spellings.count {
                    spellings.append(keyword)
                    lowered.append(keyword.lowercased())
                    isTheirs.append(theirs.contains(lowered[id]))
                    uses.append(0)
                    company.append(0)
                }
                uses[id] += 1
                withTheirs = withTheirs || isTheirs[id]
                photoIDs.append(id)
            }
            if withTheirs {
                for id in photoIDs { company[id] += 1 }
            }
        }
        let everyTarget = targets.isEmpty ? [] : Self.keywordsOnEvery(targets)
        let near = typed.isEmpty ? spellingsNear(targets) : []
        var pool: [String: Suggestion] = [:]
        for (id, spelling) in spellings.enumerated() {
            let key = lowered[id], count = uses[id]
            guard !everyTarget.contains(key) else { continue }
            if !typed.isEmpty, !key.hasPrefix(typed), !key.split(separator: " ").contains(where: { $0.hasPrefix(typed) }) {
                continue
            }
            var entry = pool[key] ?? Suggestion(name: spelling, first: false, company: 0, count: 0, nameCount: 0)
            if count > entry.nameCount || (count == entry.nameCount && spelling < entry.name) {
                entry.name = spelling
                entry.nameCount = count
            }
            entry.first = entry.first || (typed.isEmpty ? near.contains(spelling) : key.hasPrefix(typed))
            entry.company += company[id]
            entry.count += count
            pool[key] = entry
        }
        return pool.values.sorted(by: Suggestion.ranksBefore).prefix(limit).map(\.name)
    }

    /// The photos the keyword edits act on: the cull targets, in catalog order.
    private var keywordTargets: [PhotoItem] {
        let ids = cullTargets
        if ids.count == 1, let id = ids.first {
            for index in items.indices where items[index].id == id { return [items[index]] }
            return []
        }
        return ids.isEmpty ? [] : items.filter { ids.contains($0.id) }
    }

    /// Adds `names` to the cull targets as one step, kept sorted without regard to case.
    private mutating func addKeywordNames(_ names: [String]) {
        let ids = cullTargets
        guard !ids.isEmpty, !names.isEmpty else { return }
        let keyed = names.map { ($0, $0.lowercased()) }
        let name = names.count == 1 ? "Add Keyword" : "Add Keywords"
        recordEdit(name, ids: ids) { $0.keywords = Self.adding(keyed, to: $0.keywords) }
    }

    /// `keywords` (sorted without regard to case) with the `(name, lowercased)`
    /// pairs it lacks in any case, each put in its place by a binary search,
    /// so only a few names per photo are lowercased.
    private static func adding(_ keyed: [(String, String)], to keywords: [String]) -> [String] {
        var result = keywords
        for (name, key) in keyed {
            if (result.last?.lowercased() ?? "") < key {  // after them all: one name lowercased
                result.append(name)
                continue
            }
            var low = 0, high = result.count  // the first keyword at or after `key` in any case
            while low < high {
                let mid = (low + high) / 2
                if result[mid].lowercased() < key { low = mid + 1 } else { high = mid }
            }
            if result.indices.contains(low), result[low].lowercased() == key { continue }
            result.insert(name, at: low)
        }
        return result
    }

    /// Trimmed, inner spaces collapsed, empty dropped, deduplicated without
    /// regard to case (the first spelling wins), then each in the catalog's
    /// existing spelling when it has one.
    private func normalizedKeywords(_ pieces: [String]) -> [String] {
        var seen: Set<String> = []
        let names = pieces.map(Self.collapsed).filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        guard !names.isEmpty else { return [] }
        var spelling: [String: String] = [:]
        // A name ending in an ASCII byte lowercases to one ending in that byte
        // lowercased, so most of a large catalog is passed over unhashed.
        var endings = [Bool](repeating: false, count: 128)  // by ASCII byte
        for last in seen.compactMap({ $0.utf8.last }) where last < 0x80 { endings[Int(last)] = true }
        var checked: Set<String> = []  // each spelling is lowercased once
        for index in items.indices where spelling.count < names.count {
            for keyword in items[index].keywords where Self.mayEnd(keyword, in: endings) && checked.insert(keyword).inserted {
                let key = keyword.lowercased()
                if seen.contains(key), spelling[key] == nil { spelling[key] = keyword }
            }
        }
        return names.map { spelling[$0.lowercased()] ?? $0 }
    }

    /// Whether `keyword` lowercased can end in one of `endings`: false only
    /// for an ASCII last byte none of them is.
    private static func mayEnd(_ keyword: String, in endings: [Bool]) -> Bool {
        guard let last = keyword.utf8.last, last < 0x80 else { return true }
        return endings[Int(last >= 0x41 && last <= 0x5A ? last | 0x20 : last)]
    }

    /// The spellings on photos taken within an hour of any of `targets`.
    private func spellingsNear(_ targets: [PhotoItem]) -> Set<String> {
        let dates = targets.map(\.captureDate).sorted()
        guard !dates.isEmpty else { return [] }
        var near: Set<String> = []
        for photo in items where !photo.keywords.isEmpty {
            var low = 0, high = dates.count  // the first target date at or after the photo's
            while low < high {
                let mid = (low + high) / 2
                if dates[mid] < photo.captureDate { low = mid + 1 } else { high = mid }
            }
            let gaps = [low - 1, low].filter(dates.indices.contains).map { abs(dates[$0].timeIntervalSince(photo.captureDate)) }
            if gaps.contains(where: { $0 <= 3_600 }) { near.formUnion(photo.keywords) }
        }
        return near
    }

    /// The lowercased keywords every photo in `photos` has.
    private static func keywordsOnEvery(_ photos: [PhotoItem]) -> Set<String> {
        photos.dropFirst().reduce(Set(photos.first?.keywords.map { $0.lowercased() } ?? [])) { every, photo in
            every.intersection(photo.keywords.map { $0.lowercased() })
        }
    }

    /// `text` trimmed, with each run of inner whitespace as one space.
    private static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

/// Numbers spellings by an open-addressed table of `String.hashValue`s,
/// cheaper than a dictionary in a debug build.
private struct SpellingNumbers {
    private var slots = [Int](repeating: -1, count: 64)  // a spelling's number, or -1
    private var used = 0

    /// `keyword`'s number in `spellings`, else `spellings.count`, which it then takes.
    mutating func id(of keyword: String, in spellings: [String]) -> Int {
        let mask = slots.count - 1
        var slot = keyword.hashValue & mask
        while slots[slot] >= 0 {
            if spellings[slots[slot]] == keyword { return slots[slot] }
            slot = (slot + 1) & mask
        }
        slots[slot] = spellings.count
        used += 1
        if used * 2 > slots.count { grow(spellings + [keyword]) }
        return spellings.count
    }

    private mutating func grow(_ spellings: [String]) {
        slots = [Int](repeating: -1, count: slots.count * 2)
        let mask = slots.count - 1
        for (id, spelling) in spellings.enumerated() {
            var slot = spelling.hashValue & mask
            while slots[slot] >= 0 { slot = (slot + 1) & mask }
            slots[slot] = id
        }
    }
}

/// A suggestion being ranked: its shown spelling and what it ranks by.
private struct Suggestion {
    var name: String
    var first: Bool  // the whole name starts with the prefix; with none, near a target in time
    var company: Int  // photos where it keeps the targets' keywords company
    var count: Int  // photos with it
    var nameCount: Int  // photos with the shown spelling

    static func ranksBefore(_ a: Suggestion, _ b: Suggestion) -> Bool {
        if a.first != b.first { return a.first }
        if a.company != b.company { return a.company > b.company }
        if a.count != b.count { return a.count > b.count }
        return a.name.lowercased() < b.name.lowercased()
    }
}

extension MetadataInspectorID {
    /// The Keywords row's add field.
    public static let keywordsField = "library.metadata.keywords"
    /// The Title field.
    public static let title = "library.metadata.title"
    /// The Caption field.
    public static let caption = "library.metadata.caption"
    /// The Sidecar row's text.
    public static let sidecar = "library.metadata.sidecar"

    /// The token for keyword `name`; the same whatever its case.
    public static func keyword(_ name: String) -> String {
        "library.metadata.keyword.\(name.lowercased())"
    }

    /// The remove button on keyword `name`'s token.
    public static func removeKeyword(_ name: String) -> String {
        "library.metadata.removeKeyword.\(name.lowercased())"
    }
}
