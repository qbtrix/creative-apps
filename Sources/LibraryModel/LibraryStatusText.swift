// LibraryStatusText.swift: what the row under Library's content and the
// inspector's header say, as values the views draw (status-and-layout SL-2).
// `statusRow` gives the size text, the zoom and the pills after them: the
// selection (styled `.selected`), the cell size, then import, render, save
// and Preview data. The grid has no zoom; the loupe's is its scale, or the
// fit scale the view measured while it fits (`shownZoom(fitScale:)`), so the
// row never shows zoom twice. The loupe's place is left to its HUD. A failed
// render or save is an `.error` pill. The "Preview
// data" pill is last and carries `previewDataHelp`, so a consumer that draws
// it through ViewerStatusBar's `preview:` takes `row.preview` and the rest
// from `row.trailing`. Reads `order`, never a sorted copy, so a frame never
// sorts. `inspectorHeader` names the collection or the selection with its
// facts (SL-5): one photo's Captured, Size and Kind, or several photos'
// active photo (the Sync source) and capture span. Dates are written by hand
// (days-from-civil, proleptic Gregorian, no Calendar or formatted()) so Linux
// and macOS agree. Linux-safe.

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One pill in the status row; `id` names it in `library.status.<id>`.
public struct LibraryStatusPill: Hashable, Sendable, Identifiable {
    /// `.selected` draws as an on toggle; `.error` is a failed render or save.
    public enum Style: Hashable, Sendable { case plain, selected, warning, error }
    /// selection, cellSize, import, render, save or preview.
    public let id: String
    public let text: String
    /// The tooltip and accessibility hint.
    public let help: String
    public let style: Style

    public init(id: String, text: String, help: String, style: Style = .plain) {
        self.id = id; self.text = text; self.help = help; self.style = style
    }
}

/// What ViewerStatusBar draws: `zoom` is the loupe's scale; nil with `fits`
/// means the loupe fits the window, nil without it the grid (no zoom pill).
public struct LibraryStatusRow: Hashable, Sendable {
    public let zoom: Double?
    /// The loupe fits the window, so its zoom is the scale the view measured.
    public let fits: Bool
    public let size: String
    public let pills: [LibraryStatusPill]

    public init(zoom: Double?, fits: Bool = false, size: String, pills: [LibraryStatusPill]) {
        self.zoom = zoom; self.fits = fits; self.size = size; self.pills = pills
    }

    /// The zoom pill's scale: `zoom`, else `fitScale` while the loupe fits,
    /// else nil (the grid, no zoom pill).
    public func shownZoom(fitScale: Double) -> Double? {
        zoom ?? (fits ? fitScale : nil)
    }

    /// The "Preview data" pill, for ViewerStatusBar's `preview:`; nil on live data.
    public var preview: LibraryStatusPill? { pills.last { $0.id == "preview" } }

    /// Every pill but "Preview data", for ViewerStatusBar's trailing slot.
    public var trailing: [LibraryStatusPill] { pills.filter { $0.id != "preview" } }
}

/// The inspector's header: a title and its labelled facts.
public struct LibraryInspectorHeader: Hashable, Sendable {
    public struct Fact: Hashable, Sendable {
        public let label: String
        public let value: String
        public init(label: String, value: String) { self.label = label; self.value = value }
    }

    public let title: String
    public let facts: [Fact]

    public init(title: String, facts: [Fact]) { self.title = title; self.facts = facts }
}

extension LibraryCatalog {
    /// What the "Preview data" pill means, as its tooltip and accessibility hint.
    public static let previewDataHelp = "This window shows built-in sample data, not photos on disk."

    /// The cell-size pill's tooltip: what it measures and where to change it (#3130).
    public static let cellSizeHelp =
        "Thumbnail width; change it with View > Larger Thumbnails or View > Smaller Thumbnails."

    /// The row under the content; nil when there is nothing to say (an empty live catalog).
    public var statusRow: LibraryStatusRow? {
        if isEmpty {
            let empty = LibraryStatusRow(zoom: nil, size: Self.photoCountText(0), pills: progressPills(photo: nil))
            return services.isPreview ? empty : nil
        }
        // `items` often holds the photo at its place in `order` (All Photos by
        // capture date), so that slot is tried before the scan.
        if mode == .loupe, let id = focusedItemID, let index = order.firstIndex(of: id),
           let photo = items.indices.contains(index) && items[index].id == id
               ? items[index] : items.first(where: { $0.id == id }) {
            let zoom = Self.statusZoom(loupeZoom)
            let size = "\(photo.pixelSize.width) × \(photo.pixelSize.height) px"
            return LibraryStatusRow(zoom: zoom, fits: zoom == nil, size: size, pills: progressPills(photo: photo))
        }
        let picked = LibraryStatusPill(
            id: "selection", text: "\(selection.count) selected", help: "Photos selected in the grid.", style: .selected)
        let chosen = selection.isEmpty ? [] : [picked]
        let cell = LibraryStatusPill(id: "cellSize", text: "Thumbnails \(cellSize) pt", help: Self.cellSizeHelp)
        let pills = chosen + [cell] + progressPills(photo: nil)
        return LibraryStatusRow(zoom: nil, size: Self.photoCountText(order.count), pills: pills)
    }

    /// The inspector's header. `utcOffset` is the local offset in seconds
    /// (the view passes TimeZone.current's); tests pass 0. Nothing selected:
    /// the collection's name and "Photos N"; one photo: its name, Captured,
    /// Size and Kind; several: "N Photos", the active photo (the Sync
    /// source) and the capture span.
    public func inspectorHeader(utcOffset: Int) -> LibraryInspectorHeader {
        let photos = items.filter { selection.contains($0.id) }
        guard let metadata = PhotoMetadata(photos), let first = photos.first else {
            let name = selectedCollection?.name ?? userCollections.first { $0.id == selectedCollectionID }?.name ?? ""
            return LibraryInspectorHeader(title: name, facts: [.init(label: "Photos", value: "\(order.count)")])
        }
        if photos.count == 1 {
            return LibraryInspectorHeader(title: metadata.title, facts: [
                .init(label: "Captured", value: Self.dateText(first.captureDate, utcOffset: utcOffset)),
                .init(label: "Size", value: "\(first.pixelSize.width) × \(first.pixelSize.height)"),
                .init(label: "Kind", value: Self.kind(first.path)),
            ])
        }
        let dates = photos.map(\.captureDate)
        let (low, high) = (dates.min() ?? first.captureDate, dates.max() ?? first.captureDate)
        let earliest = Self.dayText(low, utcOffset: utcOffset), latest = Self.dayText(high, utcOffset: utcOffset)
        let span = earliest == latest ? earliest : "\(earliest) – \(latest)"
        // The active photo, the one Sync copies from, so the grid's heavier ring has a name (#3636).
        let active = syncSource.map { [LibraryInspectorHeader.Fact(label: "Active", value: $0.name)] } ?? []
        return LibraryInspectorHeader(title: metadata.title, facts: active + [.init(label: "Captured", value: span)])
    }

    /// "YYYY-MM-DD HH:MM" at `utcOffset` seconds from UTC; "" for a date
    /// too far out to write.
    static func dateText(_ date: Date, utcOffset: Int) -> String {
        guard let (day, minutes) = civilTime(date, utcOffset: utcOffset) else { return "" }
        return day + " " + LibraryFixtures.padded(minutes / 60, to: 2) + ":" + LibraryFixtures.padded(minutes % 60, to: 2)
    }

    /// "YYYY-MM-DD" at `utcOffset` seconds from UTC.
    static func dayText(_ date: Date, utcOffset: Int) -> String {
        civilTime(date, utcOffset: utcOffset)?.day ?? ""
    }

    /// The local day as "YYYY-MM-DD" and the minutes into it; nil past
    /// ±10^14 seconds or for a non-finite date.
    private static func civilTime(_ date: Date, utcOffset: Int) -> (day: String, minutes: Int)? {
        let seconds = date.timeIntervalSince1970.rounded(.down)
        guard seconds.isFinite, abs(seconds) < 1e14, abs(utcOffset) < 1_000_000 else { return nil }
        let local = Int(seconds) + utcOffset
        let days = floorDiv(local, 86_400)
        let (year, month, day) = civil(fromDays: days)
        let text = (year < 0 ? "-" : "") + LibraryFixtures.padded(abs(year), to: 4) + "-"
            + LibraryFixtures.padded(month, to: 2) + "-" + LibraryFixtures.padded(day, to: 2)
        return (text, (local - days * 86_400) / 60)
    }

    /// Division rounding toward negative infinity; `divisor` is positive.
    private static func floorDiv(_ value: Int, _ divisor: Int) -> Int {
        let quotient = value / divisor
        return value % divisor < 0 ? quotient - 1 : quotient
    }

    /// The proleptic Gregorian date `days` after 1970-01-01 (the inverse of
    /// days-from-civil, eras of 400 years from 0000-03-01).
    private static func civil(fromDays days: Int) -> (year: Int, month: Int, day: Int) {
        let shifted = days + 719_468
        let era = floorDiv(shifted, 146_097)
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    /// The Kind fact: "Sample" for a generated photo, JPEG, PNG or HEIC for
    /// the kinds Library imports, any other extension uppercased, else "File".
    static func kind(_ path: String?) -> String {
        guard let path else { return "Sample" }
        let name = path.split(separator: "/").last.map(String.init) ?? path
        switch PhotoFileKind.kind(forFileName: name) {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case nil:
            guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "File" }
            let ext = name[name.index(after: dot)...]
            return ext.isEmpty ? "File" : ext.uppercased()
        }
    }

    /// The zoom ViewerStatusBar shows: 100% for `.actual`, a finite positive
    /// scale as it is, nil (the measured fit scale) for fit or a scale that isn't one.
    static func statusZoom(_ zoom: LoupeZoom) -> Double? {
        switch zoom {
        case .fit: nil
        case .actual: 1
        case .scale(let scale): scale.isFinite && scale > 0 ? scale : nil
        }
    }

    /// Import, the loupe photo's render (`photo` is it; nil in the grid),
    /// save problems, then Preview data.
    private func progressPills(photo: PhotoItem?) -> [LibraryStatusPill] {
        var pills: [LibraryStatusPill] = []
        if case .running(let progress) = importState {
            pills.append(LibraryStatusPill(id: "import", text: progress.text, help: "Photos are being imported."))
        }
        if let photo, photo.availability == .available {
            if let loupeError {
                pills.append(LibraryStatusPill(id: "render", text: "Render failed", help: loupeError, style: .error))
            } else if loupeRender == nil {
                pills.append(LibraryStatusPill(id: "render", text: "Loading", help: "The photo is being drawn."))
            } else if loupeRender?.quality == .preview {
                pills.append(
                    LibraryStatusPill(id: "render", text: "Preview", help: "A quick preview; the full render follows."))
            }
        }
        if let saveError {
            pills.append(LibraryStatusPill(id: "save", text: "Not saved", help: saveError, style: .error))
        } else if case .newer = catalogState, let message = catalogState.message {
            pills.append(LibraryStatusPill(id: "save", text: "Read only", help: message, style: .warning))
        }
        if services.isPreview {
            pills.append(
                LibraryStatusPill(id: "preview", text: "Preview data", help: Self.previewDataHelp, style: .warning))
        }
        return pills
    }
}
