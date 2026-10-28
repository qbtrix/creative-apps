// LibraryFixtures.swift: the named fixtures `-LibraryFixture <name>` loads
// (blueprint 4.1), built in code so every run sees the same photos.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor

public enum LibraryFixtures {
    /// The photos of fixture `name`; an unknown name or nil gives none.
    /// `shoot-unimported` and `cameras-unimported` give their fixture (its
    /// fakes "find" those files). `large-folders` is the large catalog's
    /// 10,000 photos in their month folders, with no files on disk; `folders`
    /// is the FOLDERS section's small tree.
    public static func photos(named name: String?) -> [PhotoItem] {
        switch name {
        case "samples": LibrarySample.items()
        case "shoot", "shoot-unimported": shoot()
        case "cameras", "cameras-unimported": cameras()
        case "large": large()
        case "large-missing": largeMissing()
        case "large-folders": largePhotos(count: 10_000, folder: "/fixture/large")
        case "folders": folders()
        default: []
        }
    }

    /// 24 photos `IMG_0001` ... `IMG_0024`; every third portrait 4000 × 6000,
    /// the rest landscape 6000 × 4000. `IMG_n` is captured 2026-06-01 10:00 UTC
    /// plus `(7 · n) mod 24` minutes, so `IMG_0024` is first by capture date.
    /// Ids equal paths, as for an imported photo.
    static func shoot() -> [PhotoItem] {
        let start = Date(timeIntervalSince1970: 1_780_308_000)  // 2026-06-01 10:00 UTC
        return (1...24).map { n in
            let name = "IMG_" + padded(n, to: 4)
            let path = "/fixture/shoot/" + name + ".jpg"
            let fraction = Double(n) / 24
            return PhotoItem(
                id: path, name: name, captureDate: start.addingTimeInterval(Double((7 * n) % 24) * 60),
                color: Color3(0.25 + 0.5 * fraction, 0.45, 0.75 - 0.5 * fraction), path: path,
                pixelSize: n % 3 == 0 ? PixelSize(width: 4000, height: 6000) : PixelSize(width: 6000, height: 4000))
        }
    }

    /// The shoot's 24 photos under `/fixture/cameras/`, with invented camera
    /// details and keywords (metadata-more). `IMG_n` is shot on `Fixture
    /// Optics` `FX-1` (odd n) or `FX-2` (even); n mod 3 picks the lens: 1 the
    /// 24-70mm F2.8 at f/2.8 and 24, 35, 50, 70 mm in turn, 2 the 50mm F1.8 at
    /// f/1.8 and 50 mm, 0 the 100mm F2.8 Macro at f/8 and 100 mm; the shutter
    /// cycles 1/2000, 1/500, 1/125, 1/30 s and the ISO doubles from 100 to
    /// 6400. `IMG_0024` has no details (a file without Exif). Keywords: Beach
    /// on 1–4, 13 and 14; Sunset on 3–6; Summer on 20.
    static func cameras() -> [PhotoItem] {
        shoot().enumerated().map { index, photo in
            let n = index + 1
            let path = "/fixture/cameras/" + photo.name + ".jpg"
            var keywords: [String] = []
            if [1, 2, 3, 4, 13, 14].contains(n) { keywords.append("Beach") }
            if (3...6).contains(n) { keywords.append("Sunset") }
            if n == 20 { keywords.append("Summer") }
            return PhotoItem(
                id: path, name: photo.name, captureDate: photo.captureDate, color: photo.color, path: path,
                pixelSize: photo.pixelSize, keywords: keywords, camera: n == 24 ? .none : camera(n))
        }
    }

    /// The `cameras` fixture's details for `IMG_n`; none below 1.
    static func camera(_ n: Int) -> CameraDetails {
        guard n >= 1 else { return .none }
        let zoomFocals: [Double] = [24, 35, 50, 70]
        let shutters = [1.0 / 2000, 1.0 / 500, 1.0 / 125, 1.0 / 30]
        let (lens, fNumber, focal): (String, Double, Double) = switch n % 3 {
        case 1: ("24-70mm F2.8", 2.8, zoomFocals[((n - 1) / 3) % zoomFocals.count])
        case 2: ("50mm F1.8", 1.8, 50)
        default: ("100mm F2.8 Macro", 8, 100)
        }
        return CameraDetails(
            make: "Fixture Optics", model: n % 2 == 1 ? "FX-1" : "FX-2", lens: lens, iso: 100 << ((n - 1) % 7),
            exposureTime: shutters[(n - 1) % shutters.count], fNumber: fNumber, focalLength: focal)
    }

    /// 10,000 records `IMG_00001` ... spread evenly over 365 days from
    /// 2026-01-01 00:00 UTC; the colors cycle so the grid isn't flat.
    static func large() -> [PhotoItem] {
        let count = 10_000
        let start = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01 00:00 UTC
        let step = 365.0 * 86_400 / Double(count)
        return (0..<count).map { index in
            let shade = Double(index % 32) / 31
            return PhotoItem(
                name: "IMG_" + padded(index + 1, to: 5), captureDate: start.addingTimeInterval(Double(index) * step),
                color: Color3(shade, 0.5, 1 - shade))
        }
    }

    /// `large` with every twentieth photo's file missing: 500 missing badges to scroll past (catalog-files LC-4).
    static func largeMissing() -> [PhotoItem] {
        large().enumerated().map { index, photo in
            var photo = photo
            if index % 20 == 19 { photo.availability = .missing }
            return photo
        }
    }

    /// The shoot's first nine photos in five folders under `/fixture/Photos`: one in `trips`, two in
    /// `trips/2025`, one in `trips/2026`, one in `trip` (a name prefix of trips) and four in `family`, whose
    /// files are all missing.
    static func folders() -> [PhotoItem] {
        let places = ["trips", "trips/2025", "trips/2025", "trips/2026", "trip", "family", "family", "family", "family"]
        return zip(shoot(), places).map { photo, place in
            let path = "/fixture/Photos/\(place)/\(photo.name).jpg"
            return PhotoItem(
                id: path, name: photo.name, captureDate: photo.captureDate, color: photo.color, path: path,
                pixelSize: photo.pixelSize, availability: place == "family" ? .missing : .available)
        }
    }

    /// `value` in decimal, zero-padded on the left to `width` digits.
    static func padded(_ value: Int, to width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(width - digits.count, 0)) + digits
    }
}
