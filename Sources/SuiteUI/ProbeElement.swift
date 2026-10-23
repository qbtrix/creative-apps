// ProbeElement.swift: the one hidden element a journey reads a value from
// (`halo.file`, `flare.file`, `halo.controls`, `halo.timeline.keys`, ...).
// XCUITest reads SwiftUI accessibility values as empty strings (#262), so
// the value travels as the element's label; `value` also sets it as the value
// for VoiceOver. It draws nothing and takes no hits, so the app audit finds no
// control in it. It fills its container unless `size` pins it (a 1 x 1 pt
// readout stays under the audit's text-measuring threshold). With `rect` it
// is a canvas mark's probe instead: a clear box at `rect` (document points)
// times `zoom`, from the container's top leading corner, with `traits`.
import SwiftUI

public struct ProbeElement: View {
    public let identifier: String
    public let label: String
    public let value: String?
    public let size: CGSize?
    public let rect: CGRect?
    public let zoom: Double
    public let traits: AccessibilityTraits

    public init(
        _ identifier: String, label: String, value: String? = nil, size: CGSize? = nil, rect: CGRect? = nil,
        zoom: Double = 1, traits: AccessibilityTraits = []
    ) {
        self.identifier = identifier
        self.label = label
        self.value = value
        self.size = size
        self.rect = rect
        self.zoom = zoom
        self.traits = traits
    }

    @ViewBuilder public var body: some View {
        if let rect {
            let box = rect.applying(CGAffineTransform(scaleX: zoom, y: zoom)).standardized
            Color.clear
                .frame(width: box.width, height: box.height)
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: label))
                .accessibilityIdentifier(identifier)
                .accessibilityAddTraits(traits)
                .padding(.leading, box.minX)
                .padding(.top, box.minY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
        } else {
            plain
        }
    }

    @ViewBuilder private var plain: some View {
        let element = Color.clear
            .frame(width: size?.width, height: size?.height)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: label))
        if let value {
            element.accessibilityValue(Text(verbatim: value)).accessibilityIdentifier(identifier)
        } else {
            element.accessibilityIdentifier(identifier)
        }
    }
}
