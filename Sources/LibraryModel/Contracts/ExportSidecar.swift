// Contracts/ExportSidecar.swift (EX-1 slot, filled by EX-16): the XMP beside an export, Library-local (#3091).
// The packet follows the XMP spec (ISO 16684-1): `xmp:Rating` with -1 for a
// reject, `xmp:Label`, `xmp:CreateDate`; the pick and develop settings go in
// a Library namespace. Values are escaped by SuiteModel's `XMLText`. The
// export's `ExportMetadata` leaves out what `ExportRules.dropped` names; the
// Library namespace always stays.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteImaging
import SuiteKernel
import SuiteModel

public enum ExportSidecar {
    /// Why sidecars can't be written yet; nil now that the packet is built.
    public static let unavailable: String? = nil

    /// `IMG_0001 2.jpg` → `IMG_0001 2.xmp`: the last extension swapped (final).
    public static func fileName(for imageName: String) -> String {
        guard let dot = imageName.lastIndex(of: "."), dot != imageName.startIndex else { return imageName + ".xmp" }
        return String(imageName[..<dot]) + ".xmp"
    }

    /// The XMP packet for `photo` as exported under `metadata`, UTF-8, attributes in a fixed order.
    public static func xmp(for photo: PhotoItem, metadata: ExportMetadata) -> Data? {
        let head = XMPSidecar.head + "<rdf:Description rdf:about=\"\" xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\" "
            + "xmlns:library=\"\(XMPSidecar.libraryNamespace)\""
        let body = kept(attributes(for: photo), metadata: metadata).map { " \($0.name)=\"\(XMLText.escaped($0.value))\"" }.joined()
        return Data((head + body + "/></rdf:RDF></x:xmpmeta>").utf8)
    }

    /// Rating, label, date, name, flag, each slider off zero (panel order), then the crop.
    static func attributes(for photo: PhotoItem) -> [(name: String, value: String)] {
        var out: [(name: String, value: String)] = []
        out.append(("xmp:Rating", photo.flag == .reject ? "-1" : String(photo.rating)))
        if let label = photo.label { out.append(("xmp:Label", label.rawValue)) }
        out.append(("xmp:CreateDate", photo.captureDate.formatted(.iso8601)))
        out.append(("library:Name", photo.name))
        if photo.flag != .none { out.append(("library:Flag", photo.flag.rawValue.lowercased())) }
        let develop = photo.develop
        for slider in ToneSlider.develop where develop.value(slider) != 0 {
            out.append(("library:" + slider.title, number(develop.value(slider))))
        }
        if let crop = develop.crop {
            out.append(("library:CropAngle", number(crop.angle)))
            let rect = [crop.rect.x, crop.rect.y, crop.rect.width, crop.rect.height]
            out.append(("library:Crop", rect.map(number).joined(separator: " ")))
        }
        return out
    }

    /// The attributes `metadata` keeps: every one not in `ExportRules.dropped(metadata).xmp`,
    /// and Library's own namespace always (export-pack, LX-3).
    static func kept(_ attributes: [(name: String, value: String)],
                     metadata: ExportMetadata) -> [(name: String, value: String)] {
        let dropped = ExportRules.dropped(metadata).xmp
        return attributes.filter { $0.name.hasPrefix("library:") || !dropped.contains($0.name) }
    }

    /// `2` for a whole value, else the shortest round-tripping decimal (`0.5`).
    static func number(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int(value)) }
        return String(value)
    }
}
