// PhotoExport+Kernel.swift (export-pack PX-1 stubs, PX-3 bodies): Photo's export
// on SuiteKernel's one export options model. Photo's scope is the flattened
// image; its formats are the suite's four stills (PNG, JPEG, HEIC, TIFF) from
// `ExportFormats.all`. The sheet (`SuiteExportSheet`), the size rule
// (`ExportRules.pixels`) and the option schema are the kernel's; this file only
// maps Photo onto them. Stub: `exportPixels` gives the flattened image as
// `exportPixels(as:)` does today and ignores the size until PX-3. Linux-safe.
import SuiteKernel

extension PhotoWorkspace {
    /// The formats Photo's export offers, in the suite's order: png, jpeg, heic, tiff.
    public static let exportFormats: [ExportFormatSpec] = ExportFormats.all.filter { $0.kind == .still }

    /// What a fresh export starts from: PNG at the image's own size.
    public func exportOptionsDefault() -> SuiteExportOptions {
        SuiteExportOptions(format: "png", size: .scale(1), quality: 0.9)
    }

    /// The flattened image's pixels for `o`: as is for formats that keep
    /// transparency, on opaque white for JPEG. Throws with no image open.
    /// Stub (PX-1): `o.size` is ignored until PX-3.
    public func exportPixels(_ o: SuiteExportOptions) throws -> DecodedImage {
        let keepsAlpha = Self.exportFormats.first { $0.id == o.format }?.keepsAlpha ?? true
        return try exportPixels(as: keepsAlpha ? .png : .jpeg)
    }
}
