// SampleOptions.swift: the eyedropper's own options in the inspector, under
// its one-line hint (ToolOptionsSection): SuiteUI's SampleSizeChips (Point,
// 3 x 3, 5 x 5) on the workspace's sample size. A chip asks the window to
// change it (`.sample(.size)`); values in, intents out.
import PhotoModel
import SuiteUI
import SwiftUI

struct SampleOptions: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        SampleSizeChips(size: model.sampleSize) { perform(.sample(.size($0))) }
    }
}
