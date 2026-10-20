// Contracts/XMPSidecar.swift (metadata-more MD-4 slot, filled by MD-15 and
// MD-16): the XMP packet Library keeps beside each photo file, the name it
// goes by, and the catalog's plan of what to write. Inert until then: no
// bytes, no Library marker, no writes, no status. MD-15 writes Dublin Core and
// XMP Basic properties plus `lib:Writer`, escaping with SuiteModel's
// `XMLText` as `ExportSidecar` does. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum XMPSidecar {
    /// The sidecar's UTF-8 packet for `fields`. MD-15; empty until then.
    public static func encode(_ fields: SidecarFields) -> Data { Data() }

    /// Whether `data` carries Library's `lib:Writer` marker. MD-15; false until then.
    public static func isWrittenByLibrary(_ data: Data) -> Bool { false }

    /// `IMG_0001.xmp` beside `IMG_0001.jpg`, or `IMG_0001.jpg.xmp` when a
    /// sibling in the same folder shares the stem. MD-15; until then the
    /// full name plus `.xmp`, which never clashes.
    public static func path(for photoPath: String, siblings: Set<String>) -> String {
        photoPath + ".xmp"
    }
}

extension LibraryCatalog {
    /// The sidecars to write so each photo file's matches its fields, given
    /// what was `written`. MD-16; [] until then.
    public func sidecarWrites(after written: [String: SidecarFields]) -> [SidecarWrite] { [] }

    /// The Info tab's Sidecar row for photo `id`. MD-16; nil until then.
    public func sidecarStatus(
        for id: String, written: [String: SidecarFields], failures: [String: String], writing: Set<String>
    ) -> String? { nil }
}
