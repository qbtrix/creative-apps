// Fakes/FakeRendering.swift: fakes of the loupe, develop, crop and export
// contracts. The loupe is the photo's gradient lifted one byte level per
// slider step, develop changes nothing, crop centers the aspect, and export
// plans by the same naming rule in a few lines. The loupe and exporter obey
// `-LibraryFakeMode`, so the UI track can show every state.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import CoreRaster

public struct FakeLoupe: LoupeImaging {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func render(_ photo: PhotoItem, settings: DevelopSettings, longSide: Int,
                       quality: RenderQuality) async throws -> RenderedPhoto {
        try await FakeBehavior.perform(mode, failing: .renderFailed("the preview failed on purpose"))
        guard let base = FakeBehavior.gradient(for: FakeBehavior.cropShaped(photo, settings.crop),
                                               longSide: quality == .preview ? 512 : longSide) else {
            throw LibraryError.renderFailed("empty photo")
        }
        // Not the develop math: a visible stand-in so the UI track sees every
        // slider move. Each step of any slider (0.01 EV, or 1) lifts by one
        // byte level, clamped to the byte range.
        let steps = DevelopSlider.allCases.map { settings.value($0) / $0.step }.reduce(0, +)
        let lift = Int(min(max(steps, -255), 255).rounded())
        var bytes = base.rgba8
        var red = [Int](repeating: 0, count: HistogramBins.binCount), green = red, blue = red
        for i in stride(from: 0, to: bytes.count, by: 4) {
            for c in 0..<3 { bytes[i + c] = UInt8(min(max(Int(bytes[i + c]) + lift, 0), 255)) }
            red[Int(bytes[i])] += 1; green[Int(bytes[i + 1])] += 1; blue[Int(bytes[i + 2])] += 1
        }
        guard let image = DisplayImage(size: base.size, rgba8: bytes) else { throw LibraryError.renderFailed("size") }
        let histogram = HistogramBins(red: red, green: green, blue: blue, shadowClipped: 0, highlightClipped: 0)
        return RenderedPhoto(image: image, histogram: histogram, quality: quality)
    }
    public func prefetch(_ photos: [PhotoItem], longSide: Int) async {}
}

/// Returns the buffer unchanged and an empty histogram.
public struct FakeDevelop: DevelopRendering {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        if mode == .fail { throw LibraryError.renderFailed("the preview failed on purpose") }
        return buffer
    }
    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins { .empty }
}

/// Takes no `FakeMode` (pure geometry, nothing to fail). Centers the aspect
/// on the photo; an angle shrinks the rect by
/// cos + sin of it (a stand-in for `straightenCrop`); handle drags move the
/// matching edges by the drag, clamped to the photo, ignoring the aspect.
public struct FakeCrop: CropGeometry {
    public init() {}
    public func initial(aspect: CropAspect, angle: Double, photo: PixelSize) throws -> CropSettings {
        var rect = UnitRect.full
        if let ratio = aspect.ratio(for: photo), photo.height > 0 {
            let photoRatio = Double(photo.width) / Double(photo.height)
            if ratio < photoRatio { rect.width = ratio / photoRatio } else { rect.height = photoRatio / ratio }
            rect.x = (1 - rect.width) / 2
            rect.y = (1 - rect.height) / 2
        }
        return CropSettings(angle: min(max(angle, -45), 45), rect: rect, aspect: aspect)
    }
    public func dragged(_ crop: CropSettings, handle: CropHandle, dx: Double, dy: Double,
                        photo: PixelSize) throws -> CropSettings {
        guard photo.width > 0, photo.height > 0 else { return crop }
        let ux = dx / Double(photo.width), uy = dy / Double(photo.height)
        var r = crop.rect
        switch handle {
        case .inside: r.x += ux; r.y += uy
        case .left, .topLeft, .bottomLeft: r.x += ux; r.width -= ux
        case .right, .topRight, .bottomRight: r.width += ux
        case .top, .bottom: break
        }
        switch handle {
        case .top, .topLeft, .topRight: r.y += uy; r.height -= uy
        case .bottom, .bottomLeft, .bottomRight: r.height += uy
        default: break
        }
        r.width = min(max(r.width, 0.01), 1); r.height = min(max(r.height, 0.01), 1)
        r.x = min(max(r.x, 0), 1 - r.width); r.y = min(max(r.y, 0), 1 - r.height)
        return CropSettings(angle: crop.angle, rect: r, aspect: crop.aspect)
    }
    public func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings {
        let a = min(max(angle, -45), 45), radians = abs(a) * Double.pi / 180
        let shrink = 1 / (cos(radians) + sin(radians))
        var r = crop.rect
        let w = r.width * shrink, h = r.height * shrink
        r.x += (r.width - w) / 2; r.y += (r.height - h) / 2; r.width = w; r.height = h
        return CropSettings(angle: a, rect: r, aspect: crop.aspect)
    }
    public func frame(_ crop: CropSettings, photo: PixelSize) throws -> PixelRect {
        PixelRect(x: Int(crop.rect.x * Double(photo.width)), y: Int(crop.rect.y * Double(photo.height)),
                  width: max(Int(crop.rect.width * Double(photo.width)), 1),
                  height: max(Int(crop.rect.height * Double(photo.height)), 1))
    }
}

public struct FakeExporter: PhotoExporting {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        var taken = existingNames
        let items = photos.map { photo -> ExportPlan.Item in
            var name = photo.name + ".jpg", n = 2
            while taken.contains(name) { name = photo.name + " \(n).jpg"; n += 1 }
            taken.insert(name)
            let size = options.longEdge.map { photo.pixelSize.fitting(longSide: $0) } ?? photo.pixelSize
            return ExportPlan.Item(photoID: photo.id, fileName: name, size: size)
        }
        return ExportPlan(items: items, options: options)
    }
    public func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage {
        try await FakeBehavior.perform(mode, failing: .renderFailed("the preview failed on purpose"))
        guard let image = FakeBehavior.gradient(for: photo, longSide: item.size.longSide) else {
            throw LibraryError.renderFailed("empty photo")
        }
        return image
    }
}
