// Contracts/ExportSidecar.swift (EX-1 slot, filled by EX-16): the XMP beside an export, Library-local (#3091).
// The packet follows the XMP spec (ISO 16684-1): `xmp:Rating` with -1 for a
// reject, `xmp:Label`, `xmp:CreateDate`; the pick and develop settings go in
// a Library namespace. Values are escaped by SuiteModel's `XMLText`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

public enum ExportSidecar {
    /// Why sidecars can't be written yet; nil now that the packet is built.
    public static let unavailable: String? = nil

    /// `IMG_0001 2.jpg` → `IMG_0001 2.xmp`: the last extension swapped (final).
    public static func fileName(for imageName: String) -> String {
        guard let dot = imageName.lastIndex(of: "."), dot != imageName.startIndex else { return imageName + ".xmp" }
        return String(imageName[..<dot]) + ".xmp"
    }

    /// The XMP packet for `photo` as exported, UTF-8, attributes in a fixed order.
    public static func xmp(for photo: PhotoItem) -> Data? {
        let head = "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">"
            + "<rdf:Description rdf:about=\"\" xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\" "
            + "xmlns:library=\"https://github.com/qbtrix/creative-apps/ns/library/1.0/\""
        let body = attributes(for: photo).map { " \($0.name)=\"\(XMLText.escaped($0.value))\"" }.joined()
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
        for slider in DevelopSlider.allCases where develop.value(slider) != 0 {
            out.append(("library:" + slider.rawValue, number(develop.value(slider))))
        }
        if let crop = develop.crop {
            out.append(("library:CropAngle", number(crop.angle)))
            let rect = [crop.rect.x, crop.rect.y, crop.rect.width, crop.rect.height]
            out.append(("library:Crop", rect.map(number).joined(separator: " ")))
        }
        return out
    }

    /// `2` for a whole value, else the shortest round-tripping decimal (`0.5`).
    static func number(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int(value)) }
        return String(value)
    }
}
