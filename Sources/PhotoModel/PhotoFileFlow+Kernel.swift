// PhotoFileFlow+Kernel.swift: Photo's adapter onto the suite's file flow
// (file-flow PF-1 stubs, PF-3 bodies). PhotoWorkspace is the
// SuiteDocumentHost the shell hands every hand-off to, and the FileFlowTarget
// the shared Open Recent, Clear Menu, Open In and drop commands run on.
// It accepts open, new and place hand-offs, places dropped images as layers
// in one "Place" step, each fitted inside the canvas (never upscaled) and
// centred, leaves what only the window can do as `PhotoFileRequest`s, and
// turns the old saved recents into refs for the window's one-time import. A
// drop takes exactly the extensions the workspace's codec reads. The window
// reads dropped files from disk; the headless document reads only the bytes
// its host handed over (`receiveDropped`). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteImaging
import SuiteKernel
import SuiteModel

/// What a file-flow command asks the window to do.
public enum PhotoFileRequest: Hashable, Sendable {
    /// Open the file in a window; hand it to another app; drop a missing file from the shared recents; empty them.
    case open(path: String), handOff(path: String, app: String), forget(fileID: String), clearRecent
    /// Start a new white image of this size in an empty window or a new one (the home's New Photo, #3648).
    case newImage(width: Int, height: Int)
}

/// The file flow's state on the workspace: the window's view of the shared recents and the open file's path.
public struct PhotoFileFlowState: Sendable {
    /// Photo's recent files, newest first, as the window last read them.
    public internal(set) var recents: [RecentFileEntry] = []
    /// Where the open image lives on disk; nil until it is saved or opened from a file.
    public internal(set) var documentPath: String?
    /// What the window still has to do (oldest first), who reads each type, and the codec a placed image is read with.
    var requests: [PhotoFileRequest] = [], registry = SuiteTypeRegistry.standard, codec: any PhotoImageCodec = CoreRasterImageCodec()
    /// Dropped files' bytes by path, handed over by a host with no shared disk; nil reads the disk (the window).
    var dropped: [String: Data]?
    public init() {}
}

extension PhotoWorkspace: SuiteDocumentHost {
    /// Why Photo refuses a hand-off verb other than open, new and place.
    static let handOffRefusal = SuiteError.notAvailable("Photo only opens, creates and places images.")

    public func refusal(for handOff: HandOff) async -> SuiteError? {
        [.open, .new, .place].contains(handOff.verb) ? nil : Self.handOffRefusal
    }

    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        if let refusal = await refusal(for: handOff) { throw refusal }
        return .accepted
    }
}

extension PhotoWorkspace: FileFlowTarget {
    public var appID: String { SuiteApp.photo.rawValue }

    public var recentFiles: [RecentFileEntry] { fileFlow.recents }

    public var hasDocument: Bool { canvas != nil }

    /// The image types Photo takes into an open document as a layer: the ones its codec reads.
    public var placesExtensions: Set<String> { fileFlow.codec.readExtensions }

    public var openInApps: [String] {
        guard canvas != nil, let name = fileFlow.documentPath ?? documentName else { return [] }
        return readers(ofExtension: Self.fileExtension(name)).filter { $0 != appID }
    }

    public var openInHelp: String? {
        guard canvas != nil else { return "Open an image first." }
        let name = documentName ?? "the image"
        guard !openInApps.isEmpty else {
            let type = fileFlow.registry.type(forExtension: Self.fileExtension(fileFlow.documentPath ?? name))
            return SuiteError.noOtherReader(typeName: type?.name ?? "these").message
        }
        return fileFlow.documentPath == nil ? "Save \(name) first." : nil
    }

    /// The type's owner, then its readers, each once (SuiteDocumentsBridge's rule).
    public func readers(ofExtension ext: String) -> [String] {
        guard let type = fileFlow.registry.type(forExtension: ext) else { return [] }
        var apps: [String] = []
        for app in [type.owner].compactMap({ $0 }) + type.readers where !apps.contains(app.rawValue) { apps.append(app.rawValue) }
        return apps
    }

    public mutating func openRecent(_ fileID: String) throws {
        guard let entry = fileFlow.recents.first(where: { $0.fileID == fileID }) else {
            throw CatalogError.failed(id: "file.open-recent", message: "\(fileID) is not in Recent Files.")
        }
        guard FileManager.default.fileExists(atPath: entry.path) else {
            fileFlow.recents.removeAll { $0.fileID == fileID }
            fileFlow.requests.append(.forget(fileID: fileID))
            throw CatalogError.failed(id: "file.open-recent", message: "\(entry.name) is no longer at \(entry.path).")
        }
        fileFlow.requests.append(.open(path: entry.path))
    }

    public mutating func clearRecent() throws {
        fileFlow.recents = []
        fileFlow.requests.append(.clearRecent)
    }

    public mutating func openIn(_ app: String) throws {
        guard let path = fileFlow.documentPath, openInApps.contains(app) else {
            throw CatalogError.failed(id: "file.open-in", message: openInHelp ?? "\(app) doesn't open this image.")
        }
        fileFlow.requests.append(.handOff(path: path, app: app))
    }

    /// Reads every image to place first, so a bad file changes nothing; then one "Place" step adds a layer per
    /// image, named after its file, fitted inside the canvas and centred; "Placed at <n>%." shows when one was
    /// scaled down. Opens and hand-offs become requests; a refusal shows on the status line.
    public mutating func perform(_ actions: [DropAction]) throws {
        let placing = actions.compactMap { action -> String? in if case .place(let path) = action { path } else { nil } }
        var placed: [(name: String, tiles: TiledPixels)] = [], percent: Int?
        for path in placing {
            let name = path.split(separator: "/").last.map(String.init) ?? path
            do {
                let data: Data
                if let dropped = fileFlow.dropped {
                    guard let bytes = dropped[path] else { throw CatalogError.failed(id: "file.drop", message: path) }
                    data = bytes
                } else {
                    data = try Data(contentsOf: URL(fileURLWithPath: path))
                }
                let fitted = try droppedPixels(data)
                placed.append((Self.stem(name), fitted.tiles))
                percent = fitted.percent ?? percent
            } catch {
                throw CatalogError.failed(id: "file.drop", message: "Can't place \(name).")
            }
        }
        if let canvas, !placed.isEmpty {
            record(.stack(stackState), named: "Place")
            let center = Mask.Point(x: Double(canvas.width) / 2, y: Double(canvas.height) / 2)
            for item in placed {
                let size = ClipboardImage(image: DecodedImage(rgba8: [], width: item.tiles.width, height: item.tiles.height), source: nil)
                let rect = services.clipboard.placement(of: size, canvas: canvas, center: center)
                let above = selectedLayerID.flatMap(index(of:)) ?? 0
                let id = insertLayer(named: item.name, pixels: item.tiles, kind: .pixels, at: above)
                if let at = index(of: id) { (layers[at].offsetX, layers[at].offsetY) = (rect.x, rect.y) }
                selectedLayerID = id
            }
            statusMessage = percent.map { "Placed at \($0)%." }
            touch(.all)
        }
        for action in actions {
            switch action {
            case .open(let path): fileFlow.requests.append(.open(path: path))
            case .handOff(let path, let app): fileFlow.requests.append(.handOff(path: path, app: app))
            case .refuse(_, let reason): statusMessage = reason
            case .place: continue
            }
        }
    }

    /// Hands the next drops their files' bytes by path; from then on a drop never reads the disk.
    public mutating func receiveDropped(_ files: [String: Data]) {
        fileFlow.dropped = (fileFlow.dropped ?? [:]).merging(files) { $1 }
    }

    /// A dropped file's pixels, fitted inside the canvas by contain and never upscaled (`PlaceRules.fitted`), and
    /// the percent it was scaled to when smaller. A PNG or JPEG is read straight at the fitted size from its header's
    /// size; another file is read whole, then resampled down.
    func droppedPixels(_ data: Data) throws -> (tiles: TiledPixels, percent: Int?) {
        let codec = fileFlow.codec
        var whole: DecodedImage?
        let natural: Size
        if let size = SuiteImaging.rasterSize(of: data) { natural = size } else {
            let image = try codec.decode(data, longestSide: nil)
            (whole, natural) = (image, Size(width: Double(image.width), height: Double(image.height)))
        }
        let box = PlaceRules.fitted(natural: natural, in: placeCanvas, at: nil)
        let width = max(Int(box.width.rounded()), 1), height = max(Int(box.height.rounded()), 1)
        guard Double(width) < natural.width.rounded() || Double(height) < natural.height.rounded() else {
            return (try Self.decoded(whole ?? codec.decode(data, longestSide: nil)), nil)
        }
        let percent = Int((box.width / max(natural.width, 1) * 100).rounded())
        guard let whole else { return (try Self.placedPixels(data, codec: codec, width: width, height: height, scaled: true), percent) }
        let buffer = try PixelBuffer(rgba8: whole.rgba8, width: whole.width, height: whole.height)
        return (TiledPixels(try buffer.resized(width: width, height: height, filter: .lanczos3)), percent)
    }

    /// The open image as the suite names it, for File > Open In ▸: nil with no image, before it has a path on disk,
    /// or for a type the suite doesn't know.
    public var suiteDocument: SuiteDocumentRef? {
        guard canvas != nil, let path = fileFlow.documentPath else { return nil }
        return Self.suiteRef(path, registry: fileFlow.registry)
    }

    /// Photo's suite ref for the file at `path`; nil for a type the suite doesn't know.
    static func suiteRef(_ path: String, registry: SuiteTypeRegistry) -> SuiteDocumentRef? {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard let type = registry.type(forExtension: fileExtension(name)) else { return nil }
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .photo,
                                type: type.id, displayName: name)
    }

    /// What the file-flow commands left for the window, oldest first; empties the list.
    public mutating func takeFileRequests() -> [PhotoFileRequest] {
        defer { fileFlow.requests = [] }
        return fileFlow.requests
    }

    /// The window's latest read of Photo's shared recents (newest first) and the open file's path.
    public mutating func updateFileFlow(recents: [RecentFileEntry], documentPath: String?) {
        fileFlow.recents = recents
        fileFlow.documentPath = documentPath
    }

    /// Photo's old saved Open Recent list (newest first) as suite refs, oldest first so noting them in order keeps
    /// the newest on top; a type the suite doesn't know is dropped. Empties `stored`, so a second call imports nothing.
    public static func takeOldRecents(_ stored: inout [String]?, registry: SuiteTypeRegistry = .standard) -> [SuiteDocumentRef] {
        let paths = stored ?? []
        stored = nil
        return paths.reversed().compactMap { suiteRef($0, registry: registry) }
    }

    /// A file name's extension, lowercased; "" for none.
    static func fileExtension(_ name: String) -> String {
        let last = name.split(separator: "/").last.map(String.init) ?? name
        guard let dot = last.lastIndex(of: "."), dot != last.startIndex else { return "" }
        return String(last[last.index(after: dot)...]).lowercased()
    }

    /// A file name without its extension: the placed layer's name.
    static func stem(_ name: String) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name }
        return String(name[..<dot])
    }
}
