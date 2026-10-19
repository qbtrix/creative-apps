// LibraryStatusText.swift: what the row under Library's content and the
// inspector's header say, as values the views draw (status-and-layout SL-2).
// `statusRow` gives the size text, the zoom (nil hides ViewerStatusBar's zoom
// pill) and the pills after them: the selection, the cell size or the loupe's
// Fit and place, then import, render, save and Preview data. The "Preview
// data" pill is last and carries `previewDataHelp`, so a consumer that draws
// it through ViewerStatusBar's `preview:` takes `row.preview` and the rest
// from `row.trailing`. Reads `order`, never a sorted copy, so a frame never
// sorts. `inspectorHeader` names the collection or the selection; the facts
// for a selection come with SL-5. Linux-safe.

/// One pill in the status row; `id` names it in `library.status.<id>`.
public struct LibraryStatusPill: Hashable, Sendable, Identifiable {
    public enum Style: Hashable, Sendable { case plain, warning }
    /// selection, cellSize, zoom, position, import, render, save or preview.
    public let id: String
    public let text: String
    /// The tooltip and accessibility hint.
    public let help: String
    public let style: Style

    public init(id: String, text: String, help: String, style: Style = .plain) {
        self.id = id; self.text = text; self.help = help; self.style = style
    }
}

/// What ViewerStatusBar draws: `zoom` nil hides its zoom pill (#1184).
public struct LibraryStatusRow: Hashable, Sendable {
    public let zoom: Double?
    public let size: String
    public let pills: [LibraryStatusPill]

    public init(zoom: Double?, size: String, pills: [LibraryStatusPill]) {
        self.zoom = zoom; self.size = size; self.pills = pills
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
            let fit = zoom == nil ? [LibraryStatusPill(id: "zoom", text: "Fit", help: "The photo fits the window.")] : []
            let place = LibraryStatusPill(
                id: "position", text: "\(index + 1) of \(order.count)", help: "This photo's place in the sort.")
            let size = "\(photo.pixelSize.width) × \(photo.pixelSize.height) px"
            return LibraryStatusRow(zoom: zoom, size: size, pills: fit + [place] + progressPills(photo: photo))
        }
        let picked = LibraryStatusPill(id: "selection", text: "\(selection.count) selected", help: "Photos selected in the grid.")
        let chosen = selection.isEmpty ? [] : [picked]
        let cell = LibraryStatusPill(id: "cellSize", text: "\(cellSize) pt", help: "The thumbnails' width.")
        let pills = chosen + [cell] + progressPills(photo: nil)
        return LibraryStatusRow(zoom: nil, size: Self.photoCountText(order.count), pills: pills)
    }

    /// The inspector's header. `utcOffset` is the local offset in seconds
    /// (the view passes TimeZone.current's); tests pass 0. Nothing selected:
    /// the collection's name and "Photos N"; a selection: its title.
    public func inspectorHeader(utcOffset: Int) -> LibraryInspectorHeader {
        let photos = items.filter { selection.contains($0.id) }
        guard let metadata = PhotoMetadata(photos) else {
            let name = selectedCollection?.name ?? userCollections.first { $0.id == selectedCollectionID }?.name ?? ""
            return LibraryInspectorHeader(title: name, facts: [.init(label: "Photos", value: "\(order.count)")])
        }
        return LibraryInspectorHeader(title: metadata.title, facts: [])
    }

    /// The zoom ViewerStatusBar shows: 100% for `.actual`, a finite positive
    /// scale as it is, nil (a "Fit" pill) for fit or a scale that isn't one.
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
                pills.append(LibraryStatusPill(id: "render", text: "Render failed", help: loupeError, style: .warning))
            } else if loupeRender == nil {
                pills.append(LibraryStatusPill(id: "render", text: "Loading", help: "The photo is being drawn."))
            } else if loupeRender?.quality == .preview {
                pills.append(
                    LibraryStatusPill(id: "render", text: "Preview", help: "A quick preview; the full render follows."))
            }
        }
        if let saveError {
            pills.append(LibraryStatusPill(id: "save", text: "Not saved", help: saveError, style: .warning))
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
