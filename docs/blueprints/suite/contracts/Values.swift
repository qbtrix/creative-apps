// Values.swift: the values every suite contract shares (SuiteModel,
// planned `Sources/SuiteModel/Values/`). Foundation only, Linux-safe,
// Sendable. Pure logic that several features need (recents merge, the type
// registry, version compare) lives on these values so it is tested once.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: identity

/// The one id prefix. Placeholder until the captain names the real one (Q1).
public enum SuiteIdentity {
    public static let prefix = "org.creativesuite"
}

/// The launcher and the five apps inside AfterGlow.app.
public enum SuiteApp: String, CaseIterable, Codable, Hashable, Sendable {
    case launcher, flare, design, photo, library, halo

    /// The five apps, in the home's default order.
    public static let apps: [SuiteApp] = [.flare, .design, .photo, .library, .halo]

    public var displayName: String {
        switch self {
        case .launcher: "AfterGlow"
        case .flare: "Flare"
        case .design: "Design"
        case .photo: "Photo"
        case .library: "Library"
        case .halo: "Halo"
        }
    }

    public var bundleID: String {
        SuiteIdentity.prefix + "." + (self == .launcher ? "afterglow" : rawValue)
    }

    /// Path inside AfterGlow.app; the launcher is the bundle itself.
    public var bundlePath: String {
        self == .launcher ? "" : "Contents/Helpers/\(displayName).app"
    }

    /// Window > Switch To shortcut: Control-Command and this digit.
    public var switchDigit: Int {
        switch self {
        case .launcher: 0
        case .flare: 1
        case .design: 2
        case .photo: 3
        case .library: 4
        case .halo: 5
        }
    }
}

// MARK: types

/// A uniform type identifier, as a string so the Model stays Linux-safe.
public struct SuiteTypeID: RawRepresentable, Hashable, Codable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let flareAnimation = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".flare.animation")
    public static let designDocument = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".design.document")
    public static let haloProject = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".halo.project")
    public static let photoOpenRaster = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".photo.openraster")
    public static let handOff = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".suite.handoff")
    public static let assetEnvelope = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".suite.asset")
    public static let designLayers = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".design.layers")
    public static let flareLayers = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".flare.layers")
    public static let png = SuiteTypeID(rawValue: "public.png")
    public static let jpeg = SuiteTypeID(rawValue: "public.jpeg")
    public static let heic = SuiteTypeID(rawValue: "public.heic")
    public static let svg = SuiteTypeID(rawValue: "public.svg-image")
    public static let plainText = SuiteTypeID(rawValue: "public.utf8-plain-text")
    public static let fileURL = SuiteTypeID(rawValue: "public.file-url")
}

/// One file type the suite reads: who owns it and who else can open it.
public struct SuiteDocumentType: Hashable, Sendable {
    public var id: SuiteTypeID
    public var name: String              // "Flare Animation"; used in messages
    public var extensions: [String]      // lowercased, no dot
    public var owner: SuiteApp?          // Editor, rank Owner; nil for public types
    public var readers: [SuiteApp]       // Open In targets, default app first
    public init(id: SuiteTypeID, name: String, extensions: [String], owner: SuiteApp?, readers: [SuiteApp]) {
        self.id = id; self.name = name; self.extensions = extensions; self.owner = owner; self.readers = readers
    }
}

/// Every document type in the suite. `Bundle/Info/*.plist` mirror it, and
/// `TypeRegistryPlistTests` fails when they differ.
public struct SuiteTypeRegistry: Sendable {
    public var types: [SuiteDocumentType]
    public init(types: [SuiteDocumentType]) { self.types = types }

    public static let standard = SuiteTypeRegistry(types: [
        SuiteDocumentType(id: .flareAnimation, name: "Flare Animation", extensions: ["flare"],
                          owner: .flare, readers: [.flare, .halo]),
        SuiteDocumentType(id: .designDocument, name: "Design Document", extensions: ["design"],
                          owner: .design, readers: [.design]),
        SuiteDocumentType(id: .haloProject, name: "Halo Project", extensions: ["halo"],
                          owner: .halo, readers: [.halo]),
        SuiteDocumentType(id: .photoOpenRaster, name: "Photo Document", extensions: ["ora"],
                          owner: .photo, readers: [.photo]),
        SuiteDocumentType(id: .png, name: "PNG image", extensions: ["png"], owner: nil, readers: [.photo, .library]),
        SuiteDocumentType(id: .jpeg, name: "JPEG image", extensions: ["jpg", "jpeg"], owner: nil, readers: [.photo, .library]),
        SuiteDocumentType(id: .heic, name: "HEIC image", extensions: ["heic"], owner: nil, readers: [.photo, .library]),
    ])

    public func type(forExtension ext: String) -> SuiteDocumentType? {
        let e = ext.lowercased()
        return types.first { $0.extensions.contains(e) }
    }

    public func type(_ id: SuiteTypeID) -> SuiteDocumentType? { types.first { $0.id == id } }

    /// The app a routed open goes to: the owner, else the first reader.
    public func defaultApp(for id: SuiteTypeID) -> SuiteApp? {
        guard let t = type(id) else { return nil }
        return t.owner ?? t.readers.first
    }
}

// MARK: documents

/// A document on disk, as every app and the launcher refer to it.
public struct SuiteDocumentRef: Hashable, Codable, Sendable {
    public var path: String          // absolute path
    public var fileID: String        // stable identity (volume and file number from the app; the path when unknown)
    public var app: SuiteApp         // the app that last opened or saved it
    public var type: SuiteTypeID
    public var displayName: String   // file name with extension
    public var bookmark: Data?       // macOS bookmark data when the app has it; nil in tests and on Linux
    public init(path: String, fileID: String, app: SuiteApp, type: SuiteTypeID, displayName: String, bookmark: Data? = nil) {
        self.path = path; self.fileID = fileID; self.app = app; self.type = type
        self.displayName = displayName; self.bookmark = bookmark
    }
}

// MARK: errors

/// Every suite failure, each with the sentence the UI shows.
public enum SuiteError: Error, Equatable, Sendable {
    case appMissing(SuiteApp)
    case fileMissing(name: String)
    case unsupportedFile(name: String)
    case nothingToPaste
    case cannotPaste(app: SuiteApp, kind: String)
    case staleRevision
    case damaged(String)
    case notAvailable(String)
    case cancelled
    case timedOut
    case updateNotVerified
    case ioFailed(String)
    case noOtherReader(typeName: String)
    case originalMissing(name: String)
    case linkMissing
    case updatePostponed(SuiteApp)

    public var message: String {
        switch self {
        case .appMissing(let a): "\(a.displayName) is missing from AfterGlow. Reinstall AfterGlow to get it back."
        case .fileMissing(let n): "\(n) was moved or deleted."
        case .unsupportedFile(let n): "AfterGlow can't open \u{201C}\(n)\u{201D}. It isn't a suite document or an image."
        case .nothingToPaste: "Nothing to paste."
        case .cannotPaste(let a, let k): "\(a.displayName) can't paste \(k) yet."
        case .staleRevision: "Another app changed this at the same time. Try again."
        case .damaged(let d): "This file is damaged: \(d)."
        case .notAvailable(let r): r
        case .cancelled: "Cancelled."
        case .timedOut: "This took too long. Try again."
        case .updateNotVerified: "This update couldn't be verified, so it wasn't installed."
        case .ioFailed(let d): "Couldn't save: \(d)."
        case .noOtherReader(let t): "No other app opens \(t) files."
        case .originalMissing(let n): "The original of \(n) is missing. Locate it in Library first."
        case .linkMissing: "Linked asset is missing; using the last copy."
        case .updatePostponed(let a): "Update postponed: \(a.displayName) has unsaved changes."
        }
    }
}

// MARK: recents

public enum RecentEvent: String, Codable, Sendable { case opened, saved }

public struct RecentItem: Hashable, Codable, Sendable {
    public var ref: SuiteDocumentRef
    public var lastUsed: Date
    public var thumbnail: String?    // path relative to the store, e.g. "thumbnails/<fileID>.png"
    public init(ref: SuiteDocumentRef, lastUsed: Date, thumbnail: String? = nil) {
        self.ref = ref; self.lastUsed = lastUsed; self.thumbnail = thumbnail
    }
}

/// The one recents list. Newest first, one entry per file, at most `cap`.
public struct RecentsList: Codable, Equatable, Sendable {
    public static let cap = 200
    public var revision: Int
    public private(set) var items: [RecentItem]

    public init(revision: Int = 0, items: [RecentItem] = []) {
        self.revision = revision
        self.items = []
        for item in items { note(item) }
    }

    /// Puts the item first, replacing an older entry for the same file.
    public mutating func note(_ item: RecentItem) {
        items.removeAll { $0.ref.fileID == item.ref.fileID }
        let at = items.firstIndex { $0.lastUsed < item.lastUsed } ?? items.count
        items.insert(item, at: at)
        if items.count > Self.cap { items.removeLast(items.count - Self.cap) }
    }

    public mutating func remove(fileID: String) { items.removeAll { $0.ref.fileID == fileID } }
    public mutating func clear(app: SuiteApp) { items.removeAll { $0.ref.app == app } }

    /// Items for one app (nil: all) whose name contains the query, any case.
    public func filtered(app: SuiteApp?, query: String) -> [RecentItem] {
        let q = query.lowercased()
        return items.filter { item in
            (app == nil || item.ref.app == app) && (q.isEmpty || item.ref.displayName.lowercased().contains(q))
        }
    }

    /// Two writers raced: keep the newest entry per file from both.
    public func merging(_ other: RecentsList) -> RecentsList {
        var merged = RecentsList(revision: max(revision, other.revision), items: items)
        for item in other.items {
            if let mine = merged.items.first(where: { $0.ref.fileID == item.ref.fileID }), mine.lastUsed >= item.lastUsed {
                continue
            }
            merged.note(item)
        }
        return merged
    }
}

// MARK: new documents

public struct NewDocumentPreset: Hashable, Codable, Sendable {
    public var id: String               // "flare.vertical"
    public var app: SuiteApp
    public var title: String            // "Vertical 9:16"
    public var detail: String           // "1080 × 1920, 30 fps"
    public var parameters: [String: String]   // read by the app, e.g. ["width": "1080"]
    public init(id: String, app: SuiteApp, title: String, detail: String, parameters: [String: String] = [:]) {
        self.id = id; self.app = app; self.title = title; self.detail = detail; self.parameters = parameters
    }
}

// MARK: switching

public enum AppRunState: Equatable, Sendable {
    case notRunning, launching, running(windows: Int), missing
}

public enum SwitchReason: String, Codable, Sendable { case shortcut, menu, home, handOff }

public struct SwitchReceipt: Equatable, Sendable {
    public var app: SuiteApp
    public var wasRunning: Bool
    public var requestedAt: UInt64      // mach_continuous_time ticks; the probe pairs it with the target's frame
    public init(app: SuiteApp, wasRunning: Bool, requestedAt: UInt64) {
        self.app = app; self.wasRunning = wasRunning; self.requestedAt = requestedAt
    }
}

// MARK: hand-offs

public enum HandOffVerb: String, Codable, Sendable {
    case open, new, edit, place, importAnimation, returnEdit, openSettings
}

public enum HandOffState: String, Codable, Sendable { case pending, accepted, returned, cancelled, expired }

/// One request from one suite process to another, written as a `.aghandoff` file.
public struct HandOff: Codable, Equatable, Identifiable, Sendable {
    public static let formatVersion = 1
    public var format: Int
    public var id: String
    public var from: SuiteApp
    public var to: SuiteApp
    public var verb: HandOffVerb
    public var documents: [SuiteDocumentRef]
    public var preset: NewDocumentPreset?
    public var asset: AssetLink?
    public var settingsPane: SettingsPane?
    public var session: String?          // a round-trip session id
    public var returnTo: SuiteApp?
    public var createdAt: Date
    public var state: HandOffState

    public init(id: String, from: SuiteApp, to: SuiteApp, verb: HandOffVerb, documents: [SuiteDocumentRef] = [],
                preset: NewDocumentPreset? = nil, asset: AssetLink? = nil, settingsPane: SettingsPane? = nil,
                session: String? = nil, returnTo: SuiteApp? = nil, createdAt: Date, state: HandOffState = .pending) {
        self.format = Self.formatVersion
        self.id = id; self.from = from; self.to = to; self.verb = verb; self.documents = documents
        self.preset = preset; self.asset = asset; self.settingsPane = settingsPane; self.session = session
        self.returnTo = returnTo; self.createdAt = createdAt; self.state = state
    }

    /// Pending hand-offs older than this are expired by the next reader.
    public static let lifetime: Double = 7 * 24 * 3600

    public func isExpired(now: Date) -> Bool {
        state == .pending && now.timeIntervalSince(createdAt) > Self.lifetime
    }
}

/// The `.aghandoff` file format: sorted-key JSON; a newer format is refused by name.
public enum HandOffCodec {
    public static func encode(_ h: HandOff) throws(SuiteError) -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        do { return try e.encode(h) } catch { throw .damaged("hand-off could not be written") }
    }

    public static func decode(_ data: Data) throws(SuiteError) -> HandOff {
        struct Head: Decodable { var format: Int }
        guard let head = try? JSONDecoder().decode(Head.self, from: data) else { throw .damaged("not a hand-off") }
        guard head.format <= HandOff.formatVersion else {
            throw .notAvailable("This was sent by a newer AfterGlow. Update AfterGlow to open it.")
        }
        do { return try JSONDecoder().decode(HandOff.self, from: data) } catch { throw .damaged("hand-off fields") }
    }
}

// MARK: round trip

public struct RoundTripSource: Codable, Equatable, Sendable {
    public var catalogPhotoID: String    // Library's photo id
    public var original: SuiteDocumentRef
    public init(catalogPhotoID: String, original: SuiteDocumentRef) {
        self.catalogPhotoID = catalogPhotoID; self.original = original
    }
}

public enum RoundTripState: Codable, Equatable, Sendable {
    case open                              // Photo has it
    case saved(flattened: SuiteDocumentRef, layered: SuiteDocumentRef)
    case returned(SuiteDocumentRef)        // in Library's catalog, stacked on the original
    case cancelled
    case failed(String)
}

public struct RoundTripSession: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var source: RoundTripSource
    public var title: String               // "IMG_0002 (Library edit)"
    public var state: RoundTripState
    public var startedAt: Date
    public init(id: String, source: RoundTripSource, title: String, state: RoundTripState, startedAt: Date) {
        self.id = id; self.source = source; self.title = title; self.state = state; self.startedAt = startedAt
    }
}

// MARK: colours and assets

public enum SuiteColorSpace: String, Codable, Sendable { case sRGB, displayP3 }

/// A colour as stored: components 0...1 in their own space, never converted on save.
public struct SuiteColorValue: Codable, Hashable, Sendable {
    public var space: SuiteColorSpace
    public var red: Double, green: Double, blue: Double, alpha: Double
    public init(space: SuiteColorSpace, red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.space = space; self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// "RRGGBB" (alpha dropped), for hex rows; components clamped to 0...1.
    public var hex: String {
        func byte(_ v: Double) -> String {
            let n = Int((min(max(v, 0), 1) * 255).rounded())
            let s = String(n, radix: 16, uppercase: true)
            return s.count == 1 ? "0" + s : s
        }
        return byte(red) + byte(green) + byte(blue)
    }
}

public enum AssetKind: String, Codable, CaseIterable, Sendable { case color, vector, image, animation }

public struct SuiteAsset: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: AssetKind
    public var name: String
    public var revision: Int               // +1 on every update
    public var color: SuiteColorValue?     // kind == .color
    public var payload: String?            // "assets/<id>/<revision>.svg" for the other kinds
    public var source: SuiteDocumentRef?   // where it was added from, if anywhere
    public var modifiedAt: Date
    public init(id: String, kind: AssetKind, name: String, revision: Int = 1, color: SuiteColorValue? = nil,
                payload: String? = nil, source: SuiteDocumentRef? = nil, modifiedAt: Date) {
        self.id = id; self.kind = kind; self.name = name; self.revision = revision; self.color = color
        self.payload = payload; self.source = source; self.modifiedAt = modifiedAt
    }
}

/// What an app hands to Add to Assets.
public struct AssetDraft: Equatable, Sendable {
    public var kind: AssetKind
    public var name: String
    public var color: SuiteColorValue?
    public var payload: Data?              // SVG text, PNG bytes or a .flare file's bytes
    public var payloadExtension: String?   // "svg", "png", "flare"
    public var source: SuiteDocumentRef?
    public init(kind: AssetKind, name: String, color: SuiteColorValue? = nil, payload: Data? = nil,
                payloadExtension: String? = nil, source: SuiteDocumentRef? = nil) {
        self.kind = kind; self.name = name; self.color = color; self.payload = payload
        self.payloadExtension = payloadExtension; self.source = source
    }
}

public struct AssetIndex: Codable, Equatable, Sendable {
    public var revision: Int
    public var assets: [SuiteAsset]
    public init(revision: Int = 0, assets: [SuiteAsset] = []) { self.revision = revision; self.assets = assets }

    public func asset(_ id: String) -> SuiteAsset? { assets.first { $0.id == id } }

    /// By kind (nil: all) and name, any case, newest first.
    public func search(_ query: String, kind: AssetKind?) -> [SuiteAsset] {
        let q = query.lowercased()
        return assets
            .filter { (kind == nil || $0.kind == kind) && (q.isEmpty || $0.name.lowercased().contains(q)) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Two writers raced: per asset keep the higher revision; removals are not resurrected
    /// because a remove bumps the index revision and the remover writes last.
    public func merging(_ other: AssetIndex) -> AssetIndex {
        var byID: [String: SuiteAsset] = [:]
        for a in assets + other.assets {
            if let have = byID[a.id], have.revision >= a.revision { continue }
            byID[a.id] = a
        }
        return AssetIndex(revision: max(revision, other.revision),
                          assets: byID.values.sorted { $0.modifiedAt > $1.modifiedAt })
    }
}

/// A placed asset's memory of where it came from. Stored inside the host document.
public struct AssetLink: Codable, Hashable, Sendable {
    public var assetID: String
    public var kind: AssetKind
    public var placedRevision: Int
    public init(assetID: String, kind: AssetKind, placedRevision: Int) {
        self.assetID = assetID; self.kind = kind; self.placedRevision = placedRevision
    }
}

public enum LinkStatus: Equatable, Sendable { case current, updateAvailable(revision: Int), missing }

// MARK: pasteboard

/// One representation on the pasteboard or in a drag.
public struct TypedData: Equatable, Sendable {
    public var type: SuiteTypeID
    public var data: Data
    public init(type: SuiteTypeID, data: Data) { self.type = type; self.data = data }
}

/// The suite's own envelope: what was copied, from where, and its link if it is an asset.
public struct AssetEnvelope: Codable, Equatable, Sendable {
    public var name: String
    public var kind: AssetKind
    public var from: SuiteApp
    public var link: AssetLink?
    public var color: SuiteColorValue?
    public var svg: String?
    public init(name: String, kind: AssetKind, from: SuiteApp, link: AssetLink? = nil,
                color: SuiteColorValue? = nil, svg: String? = nil) {
        self.name = name; self.kind = kind; self.from = from; self.link = link; self.color = color; self.svg = svg
    }
}

/// What a paste or drop delivers to an app, after the suite chose the best representation.
public enum SuiteClipItem: Equatable, Sendable {
    case envelope(AssetEnvelope)
    case vector(svg: String, name: String)
    case image(png: Data, pixelWidth: Int, pixelHeight: Int)
    case color(SuiteColorValue)
    case text(String)
    case files([SuiteDocumentRef])

    public var kindName: String {
        switch self {
        case .envelope(let e): e.kind == .image ? "images" : e.kind == .color ? "colours" : "vector art"
        case .vector: "vector art"
        case .image: "images"
        case .color: "colours"
        case .text: "text"
        case .files: "files"
        }
    }
}

// MARK: preferences and settings

public enum LengthUnit: String, Codable, CaseIterable, Sendable { case points, pixels, millimeters, centimeters, inches }

public enum SettingsPane: Codable, Hashable, Sendable { case general, app(SuiteApp) }

public struct SuitePreferences: Codable, Equatable, Sendable {
    public var revision: Int
    public var units: LengthUnit
    public var autosaveSeconds: Int          // 10...600
    public var checkForUpdates: Bool
    public var onboardingDoneVersion: Int?   // nil: never finished or skipped
    public var homeOrder: [SuiteApp]
    public var perApp: [String: [String: String]]   // keyed by SuiteApp.rawValue; each app owns its keys
    public init(revision: Int = 0, units: LengthUnit = .points, autosaveSeconds: Int = 30, checkForUpdates: Bool = true,
                onboardingDoneVersion: Int? = nil, homeOrder: [SuiteApp] = SuiteApp.apps, perApp: [String: [String: String]] = [:]) {
        self.revision = revision; self.units = units; self.autosaveSeconds = min(max(autosaveSeconds, 10), 600)
        self.checkForUpdates = checkForUpdates; self.onboardingDoneVersion = onboardingDoneVersion
        self.homeOrder = homeOrder; self.perApp = perApp
    }
}

// MARK: onboarding

public enum OnboardingFocus: String, Codable, CaseIterable, Sendable { case animation, design, photos, motion, everything }

public struct OnboardingPage: Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var choices: [OnboardingFocus]    // empty except on the "what you do" page
    public init(id: String, title: String, body: String, choices: [OnboardingFocus] = []) {
        self.id = id; self.title = title; self.body = body; self.choices = choices
    }
}

// MARK: updates

public struct SuiteVersion: Comparable, Codable, Hashable, Sendable {
    public var major: Int, minor: Int, patch: Int
    public init(_ major: Int, _ minor: Int, _ patch: Int) { self.major = major; self.minor = minor; self.patch = patch }
    public init?(_ text: String) {
        let parts = text.split(separator: ".").map { Int($0) }
        guard (1...3).contains(parts.count), parts.allSatisfy({ $0 != nil }) else { return nil }
        let n = parts.compactMap { $0 } + [0, 0]
        self.init(n[0], n[1], n[2])
    }
    public static func < (a: SuiteVersion, b: SuiteVersion) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }
}

public struct UpdateOffer: Codable, Equatable, Sendable {
    public var version: SuiteVersion
    public var notes: String
    public var url: String                  // https zip of AfterGlow.app
    public var byteCount: Int
    public var signature: String            // base64 Ed25519 over the zip
    public var minimumSystem: String        // "26.0"
    public init(version: SuiteVersion, notes: String, url: String, byteCount: Int, signature: String, minimumSystem: String) {
        self.version = version; self.notes = notes; self.url = url; self.byteCount = byteCount
        self.signature = signature; self.minimumSystem = minimumSystem
    }
}

public enum UpdateFeed {
    /// The feed is a JSON array of offers; the newest above `current` wins.
    public static func newest(in data: Data, above current: SuiteVersion) throws(SuiteError) -> UpdateOffer? {
        guard let offers = try? JSONDecoder().decode([UpdateOffer].self, from: data) else { throw .damaged("update feed") }
        return offers.filter { $0.version > current }.max { $0.version < $1.version }
    }
}

// MARK: Flare in Halo

public struct AnimationSummary: Codable, Equatable, Sendable {
    public var name: String
    public var width: Double, height: Double
    public var framesPerSecond: Double
    public var frameCount: Int
    public var sceneNames: [String]
    public init(name: String, width: Double, height: Double, framesPerSecond: Double, frameCount: Int, sceneNames: [String]) {
        self.name = name; self.width = width; self.height = height
        self.framesPerSecond = framesPerSecond; self.frameCount = frameCount; self.sceneNames = sceneNames
    }
}

// MARK: home

public struct NewTile: Equatable, Sendable {
    public var app: SuiteApp
    public var title: String                 // "New Animation"
    public var presets: [NewDocumentPreset]
    public var disabledReason: String?
    public init(app: SuiteApp, title: String, presets: [NewDocumentPreset], disabledReason: String? = nil) {
        self.app = app; self.title = title; self.presets = presets; self.disabledReason = disabledReason
    }
}

public struct RecentCard: Equatable, Sendable {
    public var item: RecentItem
    public var age: String                   // "Today", "Yesterday", "Monday", "3 Oct"
    public var isMissing: Bool
    public init(item: RecentItem, age: String, isMissing: Bool) { self.item = item; self.age = age; self.isMissing = isMissing }
}

public struct HomeState: Equatable, Sendable {
    public var tiles: [NewTile]
    public var cards: [RecentCard]
    public var running: [SuiteApp]
    public var emptyMessage: String?          // set when there are no cards
    public init(tiles: [NewTile], cards: [RecentCard], running: [SuiteApp], emptyMessage: String?) {
        self.tiles = tiles; self.cards = cards; self.running = running; self.emptyMessage = emptyMessage
    }
}

/// Column math for the home's tile row and recents grid (section 7.3).
/// Widths are whole multiples of 4 pt, so every origin sits on the 4 pt grid.
public enum HomeLayout {
    public static let sidebar = 200.0, margin = 24.0, gap = 16.0, cardMin = 168.0, cardMax = 240.0
    public static let tileMax = 240.0, tileChipsMin = 160.0

    static func content(_ windowWidth: Double) -> Double { max(windowWidth - sidebar - 2 * margin, cardMin) }
    static func four(_ v: Double) -> Double { (v / 4).rounded(.down) * 4 }

    public static func columns(windowWidth: Double) -> Int {
        max(1, Int((content(windowWidth) + gap) / (cardMin + gap)))
    }

    public static func cardWidth(windowWidth: Double) -> Double {
        let n = Double(columns(windowWidth: windowWidth))
        return min(cardMax, four((content(windowWidth) - gap * (n - 1)) / n))
    }

    /// Five tiles in one row.
    public static func tileWidth(windowWidth: Double) -> Double {
        min(tileMax, four((content(windowWidth) - 4 * gap) / 5))
    }

    /// Below this width a tile shows its presets as a menu, not chips.
    public static func tileShowsChips(windowWidth: Double) -> Bool { tileWidth(windowWidth: windowWidth) >= tileChipsMin }
}

