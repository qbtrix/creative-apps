// Live/LiveCatalogCoding.swift: the catalog file, JSON `"version": 1`. One
// object with sorted keys in the encoder's pretty layout and a trailing
// newline, so equal catalogs encode to equal bytes. `captureDate` is seconds
// since 1970; `develop` is left out when neutral and `label`, `path` and the
// crop when nil, and a missing `develop` decodes as neutral settings.
// `keywords`, `title`, `caption` and `camera` (metadata-more MD-12) are
// written only when set, `camera` with only the details it has, so a catalog
// without them stays byte-equal; a missing key decodes as empty.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor

public struct LiveCatalogCoding: CatalogCoding {
    public static let unavailable: String? = nil
    /// The catalog file version this build reads and writes.
    public static let version = 1
    public init() {}

    public func encode(_ photos: [PhotoItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let file = FileV1(version: Self.version, photos: photos.map(Record.init))
        do {
            return try encoder.encode(file) + Data("\n".utf8)
        } catch {
            throw LibraryError.invalid("Library couldn't write its catalog.")
        }
    }

    public func decode(_ data: Data) throws -> [PhotoItem] {
        let decoder = JSONDecoder()
        let version = try Self.probeVersion(data)
        guard version == Self.version, let file = try? decoder.decode(FileV1.self, from: data) else {
            throw LibraryError.damagedCatalog("")
        }
        return try file.photos.map { try $0.photo() }
    }

    struct FileV1: Codable {
        var version: Int
        var photos: [Record]
    }

    /// One photo as stored; `availability` is never stored (it is checked at launch).
    struct Record: Codable {
        var camera: Camera?
        var caption: String?
        var captureDate: Double
        var color: [Double]
        var develop: DevelopSettings?
        var flag: String
        var id: String
        var keywords: [String]?
        var label: String?
        var name: String
        var path: String?
        var pixelSize: PixelSize
        var rating: Int
        var title: String?

        init(_ photo: PhotoItem) {
            camera = photo.camera.isEmpty ? nil : Camera(photo.camera)
            caption = photo.caption.isEmpty ? nil : photo.caption
            captureDate = photo.captureDate.timeIntervalSince1970
            color = [photo.color.c0, photo.color.c1, photo.color.c2]
            develop = photo.develop.isNeutral ? nil : photo.develop
            flag = photo.flag.rawValue
            id = photo.id
            keywords = photo.keywords.isEmpty ? nil : photo.keywords
            label = photo.label?.rawValue
            name = photo.name
            path = photo.path
            pixelSize = photo.pixelSize
            rating = photo.rating
            title = photo.title.isEmpty ? nil : photo.title
        }

        func photo() throws -> PhotoItem {
            guard color.count == 3, let flag = PhotoFlag(rawValue: flag) else { throw LibraryError.damagedCatalog("") }
            var photoLabel: PhotoLabel?
            if let label {
                guard let known = PhotoLabel(rawValue: label) else { throw LibraryError.damagedCatalog("") }
                photoLabel = known
            }
            return PhotoItem(
                id: id, name: name, captureDate: Date(timeIntervalSince1970: captureDate),
                color: Color3(color[0], color[1], color[2]), rating: rating, label: photoLabel, flag: flag,
                path: path, pixelSize: pixelSize, develop: develop ?? .neutral,
                keywords: keywords ?? [], title: title ?? "", caption: caption ?? "", camera: camera?.details ?? .none)
        }
    }

    /// The camera details as stored; a nil field is left out of the file.
    struct Camera: Codable {
        var exposureTime: Double?
        var fNumber: Double?
        var focalLength: Double?
        var iso: Int?
        var lens: String?
        var make: String?
        var model: String?

        init(_ details: CameraDetails) {
            exposureTime = details.exposureTime
            fNumber = details.fNumber
            focalLength = details.focalLength
            iso = details.iso
            lens = details.lens
            make = details.make
            model = details.model
        }

        var details: CameraDetails {
            CameraDetails(
                make: make, model: model, lens: lens, iso: iso,
                exposureTime: exposureTime, fNumber: fNumber, focalLength: focalLength)
        }
    }
}
