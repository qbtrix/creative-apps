// ProbeElement.swift: the one hidden element a journey reads a value from
// (`halo.file`, `flare.file`, `halo.controls`, `halo.timeline.keys`, ...).
// XCUITest reads SwiftUI accessibility values as empty strings (#262), so
// the value travels as the element's label; `value` also sets it as the value
// for VoiceOver. It draws nothing and takes no hits, so the app audit finds no
// control in it. It fills its container unless `size` pins it (a 1 x 1 pt
// readout stays under the audit's text-measuring threshold).
import SwiftUI

public struct ProbeElement: View {
    public let identifier: String
    public let label: String
    public let value: String?
    public let size: CGSize?

    public init(_ identifier: String, label: String, value: String? = nil, size: CGSize? = nil) {
        self.identifier = identifier
        self.label = label
        self.value = value
        self.size = size
    }

    public var body: some View {
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
