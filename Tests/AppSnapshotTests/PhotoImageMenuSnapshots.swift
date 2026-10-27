// PhotoImageMenuSnapshots.swift (orientation-crop OC-13): the Image menu's items, Flip Canvas
// Horizontal and Vertical among them, with no image (disabled) beside an open one, drawn in columns
// as PhotoEditMenuSnapshots does. Writes photo-image-menu-flip-canvas-{light,dark}.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoImageMenuSnapshots {
    @Test func flipCanvasItems() throws {
        var open = PhotoWorkspace()
        try open.newCanvas(width: 1920, height: 1080)
        #expect(PhotoWorkspace().orientationHelp != nil && open.orientationHelp == nil)
        let menus = [PhotoWorkspace(), open].map { PhotoMenu(model: $0, perform: { _ in }) }
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                ImageMenuStates(menus: menus), name: "photo-image-menu-flip-canvas-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }
}

private struct ImageMenuStates: View {
    let menus: [PhotoMenu]
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    PhotoImageMenu(menu: menus[index])
                }
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
