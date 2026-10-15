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
    /// `shoot-unimported` gives the shoot (its fakes "find" those files).
    public static func photos(named name: String?) -> [PhotoItem] {
        switch name {
        case "samples": LibrarySample.items()
        case "shoot", "shoot-unimported": shoot()
        case "large": large()
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

    /// `value` in decimal, zero-padded on the left to `width` digits.
    static func padded(_ value: Int, to width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(width - digits.count, 0)) + digits
    }
}
