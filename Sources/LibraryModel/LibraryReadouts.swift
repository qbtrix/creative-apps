// LibraryReadouts.swift: the accessibility values, help texts and notice the
// Library window shows. Every value is computed from the catalog's stored
// state alone, so the features that fill that state (thumbnails,
// loupe-viewport, develop, persist) never edit this file. Journeys and Linux
// tests read the same strings (blueprint 4.1). Linux-safe.

/// What the content's notice slot shows; `source` says whose dismiss closes it.
public struct LibraryNoticeContent: Hashable, Sendable {
    public enum Action: Hashable, Sendable { case showCatalogInFinder, showFailures }
    public enum Source: Hashable, Sendable { case catalog, `import`, cull }

    public var message: String
    public var isError: Bool
    public var action: Action?
    public var source: Source
    public init(message: String, isError: Bool, action: Action?, source: Source) {
        self.message = message; self.isError = isError; self.action = action; self.source = source
    }
}

extension LibraryCatalog {
    /// A grid cell's value: `unreadable`, `ready W×H` or `loading`, then the
    /// photo's `cullSummary` ("ready 256×171 3 stars, Picked, Red"). Empty for an unknown id.
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
            return LibraryNoticeContent(message: message, isError: true, action: action, source: .catalog)
        }
        if let importNotice {
            return LibraryNoticeContent(
                message: importNotice.message, isError: importNotice.isError,
                action: importNotice.failures.isEmpty ? nil : .showFailures, source: .import)
        }
        if let cullError {
            return LibraryNoticeContent(message: cullError, isError: true, action: nil, source: .cull)
        }
        return nil
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
