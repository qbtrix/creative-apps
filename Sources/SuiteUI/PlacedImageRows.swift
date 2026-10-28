// PlacedImageRows.swift: the inspector rows for a selected placed image (placed-images PL-3): the file row, then
// Replace… (the Place… panel; the first file it reads becomes `.replace`) and Reset Size (`.resetSize`), each sent
// through `onIntent`. `PlacedImageText` holds the words the rows, the view and the gallery read out.
import Foundation
import SuiteKernel
import SwiftUI

/// The rows for a placed image: "wide.png · PNG · 1200 × 400 px", then Replace… and Reset Size.
public struct PlacedImageRows: View {
    private let asset: PlacedAsset
    private let formats: Set<PlacedFormat>
    private let onIntent: (PlaceIntent) -> Void

    public init(asset: PlacedAsset, formats: Set<PlacedFormat>, onIntent: @escaping (PlaceIntent) -> Void) {
        (self.asset, self.formats, self.onIntent) = (asset, formats, onIntent)
    }

    public var body: some View {
        InspectorRow("File") {
            Text(PlacedImageText.summary(asset)).lineLimit(1).truncationMode(.middle)
        }
        // One static text read "File" with the summary as its AXValue, which a journey's `.value` reads (#4230).
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel("File")
        .accessibilityValue(PlacedImageText.summary(asset))
        .accessibilityIdentifier("suite.place.file")
        InspectorRow("") {
            HStack(spacing: SuiteSpacing.s) {
                Button("Replace…", action: replace)
                    .help("Choose another file for this image; its box stays.")
                    .suiteControl(id: "suite.place.replace", enabled: true, reason: nil)
                Button("Reset Size") { onIntent(.resetSize) }
                    .help("Size the box to the file's own proportions.")
                    .suiteControl(id: "suite.place.reset-size", enabled: true, reason: nil)
            }
        }
    }

    private func replace() {
        let (formats, onIntent) = (formats, onIntent)
        Task { @MainActor in
            guard let file = await PlacePanel.choose(formats: formats).first else { return }
            onIntent(.replace(name: file.name, data: file.data))
        }
    }
}

/// The words for a placed image.
enum PlacedImageText {
    /// "wide.png · PNG · 1200 × 400 px"; an SVG's size is in its own units, so it has no unit.
    static func summary(_ asset: PlacedAsset) -> String {
        let unit = asset.format == .svg ? "" : " px"
        return "\(asset.name) · \(asset.format.rawValue.uppercased()) · \(whole(asset.natural.width)) × \(whole(asset.natural.height))\(unit)"
    }

    /// What VoiceOver reads after "Image": "wide.png, 1200 by 400 pixels".
    static func spoken(_ asset: PlacedAsset) -> String {
        let unit = asset.format == .svg ? "" : " pixels"
        return "\(asset.name), \(whole(asset.natural.width)) by \(whole(asset.natural.height))\(unit)"
    }

    /// `value` rounded to a whole number, as text; formatting, not `Int(_:)`, so no value traps.
    static func whole(_ value: Double) -> String { String(format: "%.0f", value) }

    /// A kernel rect as a CoreGraphics one, times `scale`.
    static func cgRect(_ rect: Rect, scale: Double) -> CGRect {
        CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
    }
}
