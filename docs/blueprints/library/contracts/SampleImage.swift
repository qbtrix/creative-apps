// SampleImage.swift: the picture of a photo with no file (a generated
// sample): a left-to-right gradient from its color to half its color, at
// its pixel size fitted to a long side. Fakes and the live conformances
// both draw samples with it, so sample photos look the same on fake and
// live services. Deterministic. Linux-safe.
public enum SampleImage {
    /// `photo`'s gradient, its `pixelSize` fitted to `longSide` (nil: full size).
    public static func image(for photo: PhotoItem, longSide: Int?) -> DisplayImage? {
        let size = longSide.map { photo.pixelSize.fitting(longSide: $0) } ?? photo.pixelSize
        let color = photo.pixel
        var bytes = [UInt8]()
        bytes.reserveCapacity(size.width * size.height * 4)
        for _ in 0..<size.height {
            for x in 0..<size.width {
                let t = size.width > 1 ? Double(x) / Double(size.width - 1) : 0
                for channel in 0..<3 { bytes.append(UInt8((Double(color[channel]) * (1 - t / 2)).rounded())) }
                bytes.append(255)
            }
        }
        return DisplayImage(size: size, rgba8: bytes)
    }
}
