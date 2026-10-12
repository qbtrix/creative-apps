// PhotoInspectorSnapshots.swift: Photo's inspector with no image open (the
// "No Image" empty state), at the inspector's ideal width, in Light and Dark.
// Writes photo-inspector-no-image-light.png and
// photo-inspector-no-image-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoInspectorSnapshots {
    @Test func noImage() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                InspectorSample(model: PhotoWorkspace()),
                name: "photo-inspector-no-image-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct InspectorSample: View {
    let model: PhotoWorkspace
    var body: some View {
        PhotoInspector(model: model)
            .frame(width: SuiteSize.inspectorWidth.ideal, height: 480)
            .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
