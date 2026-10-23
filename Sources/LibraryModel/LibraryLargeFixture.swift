// LibraryLargeFixture.swift (large-catalog LG-1): a deterministic catalog of
// any size for the 10,000-photo budgets. Every photo's rating, flag, label,
// capture time, shape, shade and folder come from a seeded mix of its index,
// so two builds are equal. The files are 64 px flat-colour baseline JPEGs:
// 32 blobs (16 shades in two shapes) encoded once per build and reused, written only
// where no file exists yet. Linux-safe: no image framework, Foundation only.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor

extension LibraryFixtures {
    /// A deterministic catalog of `count` photos with generated 64 px JPEGs under `folder`.
    public static func large(count: Int, folder: String) throws -> LibraryCatalog {
        let photos = largePhotos(count: count, folder: folder)
        let files = FileManager.default
        var made: Set<String> = [], blobs: [LargeJPEG.Key: Data] = [:]
        for photo in photos {
            guard let path = photo.path, !files.fileExists(atPath: path) else { continue }
            let directory = String(path[..<(path.lastIndex(of: "/") ?? path.endIndex)])
            if made.insert(directory).inserted {
                try files.createDirectory(atPath: directory, withIntermediateDirectories: true)
            }
            try LargeJPEG.blob(for: photo, cache: &blobs).write(to: URL(fileURLWithPath: path))
        }
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        return catalog
    }

    /// The fixture's photos; with no `folder` they have no paths (the launch flag's fakes).
    /// Photo `i` is the same whatever `count` is.
    static func largePhotos(count: Int, folder: String?) -> [PhotoItem] {
        let start = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01 00:00 UTC
        let root = folder.map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
        return (0..<max(count, 0)).map { index in
            let mix = LargeJPEG.mix(UInt64(index))
            let time = Double(index) * 3_000 + Double(mix % 2_400)  // ~347 days at 10,000
            let month = min(Int(time / (30.5 * 86_400)) + 1, 12)
            let subfolder = "2026-" + padded(month, to: 2) + (index % 3 == 2 ? "/selects" : "")
            let name = "IMG_" + padded(index + 1, to: 5)
            let path = root.map { "\($0)/\(subfolder)/\(name).jpg" }
            let flagRoll = (mix >> 12) % 10
            let labelRoll = Int((mix >> 20) % 8)
            let portrait = (mix >> 28) % 4 == 0
            return PhotoItem(
                id: path, name: name, captureDate: start.addingTimeInterval(time),
                color: LargeJPEG.color(shade: Int((mix >> 36) % 16)), rating: Int((mix >> 4) % 6),
                label: labelRoll < PhotoLabel.allCases.count ? PhotoLabel.allCases[labelRoll] : nil,
                flag: flagRoll == 0 ? .reject : flagRoll < 3 ? .pick : PhotoFlag.none, path: path,
                pixelSize: portrait ? PixelSize(width: 48, height: 64) : PixelSize(width: 64, height: 48))
        }
    }
}

/// The fixture's seeded mix and its flat-colour baseline JPEG encoder.
enum LargeJPEG {
    /// SplitMix64's finalizer: a fixed, well-spread hash of `value`.
    static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// One of 16 shades: eight hues round the circle, dark then light.
    static func color(shade: Int) -> Color3 {
        let hue = Double(shade % 8) / 8, light = shade % 16 < 8 ? 0.35 : 0.7
        func channel(_ offset: Double) -> Double {
            let angle = (hue + offset).truncatingRemainder(dividingBy: 1) * 6
            return light * (0.4 + 0.6 * max(0, min(1, abs(angle - 3) - 1)))
        }
        return Color3(channel(0), channel(2.0 / 3), channel(1.0 / 3))
    }

    struct Key: Hashable { let pixel: [UInt8], width: Int, height: Int }

    /// The photo's file: one of the 32 blobs, each encoded on first use into `cache`.
    static func blob(for photo: PhotoItem, cache: inout [Key: Data]) -> Data {
        let size = photo.pixelSize
        let key = Key(pixel: photo.pixel, width: size.width, height: size.height)
        if let data = cache[key] { return data }
        let data = encode(width: size.width, height: size.height, rgb: photo.pixel)
        cache[key] = data
        return data
    }

    /// A baseline JPEG of one flat colour: quantizer 1, no subsampling, so each
    /// 8 × 8 block is its DC term (8 × (v − 128), predicted per component) and an end of block.
    static func encode(width: Int, height: Int, rgb: [UInt8]) -> Data {
        let r = Double(rgb.count > 0 ? rgb[0] : 0), g = Double(rgb.count > 1 ? rgb[1] : 0)
        let b = Double(rgb.count > 2 ? rgb[2] : 0)
        let ycc = [0.299 * r + 0.587 * g + 0.114 * b,
                   -0.1687 * r - 0.3313 * g + 0.5 * b + 128,
                   0.5 * r - 0.4187 * g - 0.0813 * b + 128].map { 8 * (Int(min(max($0.rounded(), 0), 255)) - 128) }
        func word(_ v: Int) -> [UInt8] { [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
        var out: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0, 0, 16] + Array("JFIF".utf8) + [0, 1, 1, 0, 0, 1, 0, 1, 0, 0]
        out += [0xFF, 0xDB, 0, 67, 0] + [UInt8](repeating: 1, count: 64)
        out += [0xFF, 0xC0, 0, 17, 8] + word(height) + word(width) + [3, 1, 0x11, 0, 2, 0x11, 0, 3, 0x11, 0]
        var dcBits = [UInt8](repeating: 0, count: 16), acBits = dcBits
        dcBits[3] = 12  // categories 0...11, four bits each
        acBits[0] = 1  // end of block alone, one bit
        out += [0xFF, 0xC4, 0, 49, 0x00] + dcBits + Array(0...11) + [0x10] + acBits + [0]
        out += [0xFF, 0xDA, 0, 12, 3, 1, 0, 2, 0, 3, 0, 0, 63, 0]
        var bits = BitWriter()
        let blocks = ((width + 7) / 8) * ((height + 7) / 8)
        for block in 0..<blocks {
            for dc in ycc {
                let diff = block == 0 ? dc : 0
                let category = diff == 0 ? 0 : Int.bitWidth - abs(diff).leadingZeroBitCount
                bits.put(category, count: 4)
                bits.put(diff < 0 ? diff + (1 << category) - 1 : diff, count: category)
                bits.put(0, count: 1)
            }
        }
        return Data(out + bits.finished() + [0xFF, 0xD9])
    }

    /// Entropy-coded bits, MSB first, with 0xFF stuffing and one-padding.
    struct BitWriter {
        private var bytes: [UInt8] = [], current = 0, filled = 0

        mutating func put(_ value: Int, count: Int) {
            for shift in stride(from: count - 1, through: 0, by: -1) {
                current = (current << 1) | ((value >> shift) & 1)
                filled += 1
                if filled == 8 { flush() }
            }
        }

        mutating func finished() -> [UInt8] {
            while filled != 0 { put(1, count: 1) }
            return bytes
        }

        private mutating func flush() {
            bytes.append(UInt8(current))
            if current == 0xFF { bytes.append(0) }
            current = 0
            filled = 0
        }
    }
}
