// LibraryReadouts.swift: the accessibility values, help texts and notice the
// Library window shows. Every value is computed from the catalog's stored
// state alone, so the features that fill that state (thumbnails,
// loupe-viewport, develop, persist) never edit this file. Journeys and Linux
// tests read the same strings (blueprint 4.1). Linux-safe.

/// What the content's notice slot shows; `source` says whose dismiss closes it.
public struct LibraryNoticeContent: Hashable, Sendable {
    public enum Action: Hashable, Sendable { case showCatalogInFinder, showFailures, importFolder }
    /// How a refused cull change on sample data is fixed; a cull notice
    /// ending with it offers Import Folder….
    public static let importHint = "Import a folder to rate your own photos."
    public enum Source: Hashable, Sendable { case catalog, `import`, cull }

    public var message: String
    public var isError: Bool
    public var action: Action?
    public var source: Source
    public init(message: String, isError: Bool, action: Action?, source: Source) {
        self.message = message; self.isError = isError; self.action = action; self.source = source
    }
}

/// The empty catalog's title and message, and whether it offers Import Folder….
public struct LibraryEmptyState: Hashable, Sendable {
    public var title: String
    public var message: String
    public var offersImport: Bool
    public init(title: String, message: String, offersImport: Bool) {
        self.title = title; self.message = message; self.offersImport = offersImport
    }
}

extension LibraryCatalog {
    /// A grid cell's value: `unreadable`, `ready W×H` or `loading`, then the
    /// photo's `cullSummary` ("ready 256×171 3 stars, Picked, Red label"). Empty for an unknown id.
    public func cellValue(for id: String) -> String {
        guard let photo = items.first(where: { $0.id == id }) else { return "" }
        let state: String
        if photo.availability != .available {
            state = "unreadable"
        } else if let thumbnail = thumbnails[id] {
            state = "ready " + Self.sizeText(thumbnail.size)
        } else {
            state = "loading"
        }
        return state + " " + photo.cullSummary
    }

    /// A grid cell's help: why its file can't be read, else nil.
    public func cellHelp(for id: String) -> String? {
        items.first { $0.id == id }?.availability.help
    }

    /// The loupe photo's value: `unreadable`, `preview`, `full` or `loading`,
    /// the render's W×H, its checksum under `showsTestValues`, the zoom, then
    /// `cullSummary` ("full 2048×1365 3f9a… 100% 3 stars"). Nil outside the loupe.
    public var loupeValue: String? {
        guard mode == .loupe, let id = focusedItemID, let photo = items.first(where: { $0.id == id }) else {
            return nil
        }
        var parts: [String] = []
        if photo.availability != .available {
            parts.append("unreadable")
        } else if let render = loupeRender {
            parts.append(render.quality.rawValue)
            parts.append(Self.sizeText(render.image.size))
            if showsTestValues { parts.append(render.image.checksum) }
        } else {
            parts.append("loading")
        }
        parts.append(Self.zoomText(loupeZoom))
        parts.append(photo.cullSummary)
        return parts.joined(separator: " ")
    }

    /// The loupe's glass readout: name, place and cull summary, e.g.
    /// "IMG_0055  ·  1 of 60  ·  3 stars, Picked, Red label". Nil outside the loupe.
    public var loupeReadout: String? {
        guard let photo = loupeItem, let position = loupePosition else { return nil }
        return Self.loupeReadout(for: photo, position: position)
    }

    /// The readout for `photo` at `position` ("1 of 60"), so a key's change shows in the loupe (#1661).
    public static func loupeReadout(for photo: PhotoItem, position: String) -> String {
        "\(photo.name)  ·  \(position)  ·  \(photo.cullSummary)"
    }

    /// The loupe render's histogram as `mean 0.4213`; `mean 0.0000` with no render.
    public var histogramValue: String {
        Self.histogramValue(of: loupeRender?.histogram ?? .empty)
    }

    /// `mean 0.4213`: the mean of the three channels' bin means over 0...255,
    /// divided by 255, to four decimals. An empty channel's mean is 0, never NaN.
    public static func histogramValue(of bins: HistogramBins) -> String {
        let means = [bins.red, bins.green, bins.blue].map { counts -> Double in
            var total = 0.0
            var weighted = 0.0
            for (bin, count) in counts.enumerated() where count > 0 {
                total += Double(count)
                weighted += Double(bin) * Double(count)
            }
            return total > 0 ? weighted / total : 0
        }
        let mean = means.reduce(0, +) / 3 / 255
        let tenThousandths = Int((min(max(mean, 0), 1) * 10_000).rounded())
        let fraction = String(tenThousandths % 10_000)
        return "mean \(tenThousandths / 10_000)." + String(repeating: "0", count: 4 - fraction.count) + fraction
    }

    /// `saved` when every change is on disk, else `dirty` (the `library.catalog` value).
    public var catalogValue: String {
        saveRevision == savedRevision ? "saved" : "dirty"
    }

    /// The notice slot's content, first match wins: the catalog file's
    /// problem, then the last import's result, then a refused cull change.
    public var notice: LibraryNoticeContent? {
        if let message = catalogState.message {
            let action: LibraryNoticeContent.Action? = catalogState == .damaged ? .showCatalogInFinder : nil
            // A damaged file was set aside and Library carries on (a warning);
            // a newer one is refused (an error).
            return LibraryNoticeContent(
                message: message, isError: catalogState != .damaged, action: action, source: .catalog)
        }
        if let importNotice {
            return LibraryNoticeContent(
                message: importNotice.message, isError: importNotice.isError,
                action: importNotice.failures.isEmpty ? nil : .showFailures, source: .import)
        }
        if let cullError {
            let action: LibraryNoticeContent.Action? =
                cullError.hasSuffix(LibraryNoticeContent.importHint) ? .importFolder : nil
            return LibraryNoticeContent(message: cullError, isError: true, action: action, source: .cull)
        }
        return nil
    }

    /// Whether the content shows `emptyState`: the catalog has no photos and
    /// the launch read has finished. While it runs the content stays blank,
    /// so a saved catalog never flashes "No Photos" before it appears.
    public var showsEmptyState: Bool {
        isEmpty && catalogState != .loading
    }

    /// What the empty catalog's content says, agreeing with the catalog
    /// notice above it. `importReason` is why Import Folder… can't act (nil
    /// when it can); the message then says so and points to File > Load
    /// Sample Photos. A newer catalog offers no import: nothing is saved over it.
    public func emptyState(importReason: String?) -> LibraryEmptyState {
        let hint = importReason.map { reason in
            (reason.hasSuffix(".") ? reason : reason + ".") + " Choose File > Load Sample Photos to try Library."
        }
        switch catalogState {
        case .newer:
            return LibraryEmptyState(
                title: "Catalog Not Opened",
                message: "Your photos are safe in the newer catalog. Update Library to see them.",
                offersImport: false)
        case .damaged:
            let kept = "The old catalog is kept as catalog.json.bad, and this new one starts empty."
            return LibraryEmptyState(
                title: "New Catalog Started", message: hint.map { kept + " " + $0 } ?? kept, offersImport: true)
        case .loading, .ready:
            return LibraryEmptyState(
                title: "No Photos",
                message: hint ?? "Photos you import appear here, sorted by the date they were taken.",
                offersImport: true)
        }
    }

    /// Whether File > Load Sample Photos can act: not over a newer catalog,
    /// whose "Catalog Not Opened" state must stay until Library is updated.
    public var canLoadSamples: Bool {
        if case .newer = catalogState { return false }
        return true
    }

    /// "1 photo", "26 photos": the status bar's count.
    public static func photoCountText(_ count: Int) -> String {
        count == 1 ? "1 photo" : "\(count) photos"
    }

    /// Why the services member `member` ("importer", "loupe", ...) can't act
    /// yet: a disabled control's help. Nil once it is live.
    public func help(for member: String) -> String? {
        services.unavailable[member]
    }

    private static func sizeText(_ size: PixelSize) -> String {
        "\(size.width)×\(size.height)"
    }

    /// `fit`, `100%`, or the scale as a whole percent.
    private static func zoomText(_ zoom: LoupeZoom) -> String {
        switch zoom {
        case .fit: return "fit"
        case .actual: return "100%"
        case .scale(let scale):
            guard scale.isFinite else { return "fit" }
            return "\(Int((min(max(scale, 0), 1_000) * 100).rounded()))%"
        }
    }
}
