// FlareInspectorScene.swift: the SCENE stub with nothing selected (IT-4; IT-6
// adds the controls): the scene's size and frame rate as plain rows.
import SuiteUI
import SwiftUI

struct FlareInspectorScene: View {
    let size: String
    let rate: String

    var body: some View {
        InspectorSection("Scene") {
            InspectorRow("Size") { Text(size) }
            InspectorRow("Frame rate") { Text(rate) }
        }
        .accessibilityIdentifier("flare.inspector.scene")
    }
}
