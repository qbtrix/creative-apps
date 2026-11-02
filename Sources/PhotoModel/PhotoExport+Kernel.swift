// PhotoExport+Kernel.swift (export-pack PX-1 stubs, PX-3 bodies): Photo's export
// on SuiteKernel's one export options model. Photo's scope is the flattened
// image, cut to the crop being framed when there is one; its formats are the
// suite's four stills (PNG, JPEG, HEIC, TIFF) from `ExportFormats.all`. The sheet
// (`SuiteExportSheet`), the size rule (`ExportRules.pixels`), its refusals and
// the option schema are the kernel's; this file only maps Photo onto them. The
// scope is cut first, then resampled with CoreRaster's Lanczos when the size
// differs. Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace {
    /// The formats Photo's export offers, in the suite's order: png, jpeg, heic, tiff.
    public static let exportFormats: [ExportFormatSpec] = ExportFormats.all.filter { $0.kind == .still }

    /// What a fresh export starts from: PNG at the image's own size.
    public func exportOptionsDefault() -> SuiteExportOptions {
        SuiteExportOptions(format: "png", size: .scale(1), quality: 0.9)
    }

    /// The flattened image's pixels for `o`: the framed crop (the whole image
    /// when none), resampled to `ExportRules.pixels` for `o.size`; as is for
    /// formats that keep transparency, on opaque white for the rest. Throws
    /// `ExportOptionRefusal` for options the kernel refuses (a format Photo
    /// lacks, Pixels at another shape unless stretched) and with no image open.
    public func exportPixels(_ o: SuiteExportOptions) throws -> DecodedImage {
        let image = try exportBuffer(o)
        return DecodedImage(rgba8: try image.rgba8(), width: image.width, height: image.height)
    }

    /// `exportPixels(_:)` before its 8-bit step: the premultiplied linear buffer core's encoders take, so an
    /// export can hand it to `CoreRasterImageCodec.encode(buffer:as:quality:)` without a second conversion.
    public func exportBuffer(_ o: SuiteExportOptions) throws -> PixelBuffer {
        guard let whole = canvas?.rect else { throw RasterError.invalid("no image is open") }
        let scope = pendingCrop.flatMap { whole.intersection($0) } ?? whole
        if let why = ExportRules.refusal(o, source: (scope.width, scope.height), formats: Self.exportFormats) {
            throw ExportOptionRefusal.invalid(why)
        }
        var image = try sized(rendered(scope), o)
        if Self.exportFormats.first(where: { $0.id == o.format })?.keepsAlpha == false { image = try image.onWhite() }
        return image
    }

    /// `buffer` resampled to the size `o` asks for, with Lanczos; itself when that is its size already.
    private func sized(_ buffer: PixelBuffer, _ o: SuiteExportOptions) throws -> PixelBuffer {
        let size = try ExportRules.pixels(of: (buffer.width, buffer.height), o.size, evenSize: false)
        guard (size.width, size.height) != (buffer.width, buffer.height) else { return buffer }
        return try buffer.resized(width: size.width, height: size.height, filter: .lanczos3)
    }
}
