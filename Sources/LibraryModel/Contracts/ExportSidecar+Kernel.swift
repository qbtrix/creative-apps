// Contracts/ExportSidecar+Kernel.swift (EX-1 slot, filled by EX-16): the XMP file beside an
// export. Its name is final, so ExportNames (on SuiteModel's rule) keeps it free.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum ExportSidecar {
    /// Why sidecars can't be written yet; EX-16 makes it nil.
    public static let unavailable: String? = "Sidecars aren't built yet (export sidecars)."

    /// `IMG_0001 2.jpg` → `IMG_0001 2.xmp`: the last extension swapped (final).
    public static func fileName(for imageName: String) -> String {
        guard let dot = imageName.lastIndex(of: "."), dot != imageName.startIndex else { return imageName + ".xmp" }
        return String(imageName[..<dot]) + ".xmp"
    }

    /// The XMP packet for `photo` as exported. Slot: nil.
    public static func xmp(for photo: PhotoItem) -> Data? { nil }
}
