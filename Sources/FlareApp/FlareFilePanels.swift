// FlareFilePanels.swift: the open and save panels, the title's dirty dot and
// the -FlareSaveTo / -FlareOpenFile launch paths. A no-op modifier until
// DK-12 fills it.
import FlareModel
import SwiftUI

struct FlareFilePanels: ViewModifier {
    let model: FlareWorkspace
    let launch: FlareLaunch
    let perform: @MainActor (FlareIntent) -> Void

    func body(content: Content) -> some View {
        content
    }
}
