// GalleryCrop.swift (orientation-crop OC-5): the gallery's `crop` page, CropAspectPicker beside the pick's largest
// frame on a 6000 × 4000 fake photo, which turns portrait on X, and a log line naming each command sent.
import SuiteKernel
import SwiftUI

enum GalleryCrop {
    static let name = "crop"
    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryCropPage()) }]
    static let photo = Rect(minX: 0, minY: 0, maxX: 6000, maxY: 4000)
}

struct GalleryCropPage: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    @State private var aspect: CropAspect
    @State private var orientation: CropOrientation
    @State private var log: [String] = []

    init(aspect: CropAspect = .free, orientation: CropOrientation = .landscape) {
        _aspect = State(initialValue: aspect)
        _orientation = State(initialValue: orientation)
    }

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Crop").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: SuiteSpacing.l) {
                CropAspectPicker(aspect: aspect, orientation: orientation) { pick in
                    (aspect, orientation) = (pick.aspect, pick.orientation)
                    log.append(CropAspectChoices.line(pick))
                }
                .frame(width: SuiteSize.inspectorWidth.ideal)
                GalleryCropFrame(frame: CropAspectChoices.frame(aspect, orientation, in: GalleryCrop.photo)).equatable()
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityValue(log.joined(separator: "\n")).accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The fake photo with the crop frame on it; its label and value end landscape, portrait or square.
struct GalleryCropFrame: View, Equatable {
    let frame: Rect

    var body: some View {
        let photo = GalleryCrop.photo
        let scale = SuiteSize.contentMinimum.width / 2 / photo.width
        let shape = frame.width == frame.height ? "square" : frame.height > frame.width ? "portrait" : "landscape"
        SuiteColor.artboard.frame(width: photo.width * scale, height: photo.height * scale)
            .overlay(alignment: .topLeading) {
                Rectangle().fill(SuiteColor.selectedTint).overlay(Rectangle().strokeBorder(SuiteColor.accent))
                    .frame(width: frame.width * scale, height: frame.height * scale)
                    .offset(x: frame.minX * scale, y: frame.minY * scale)
            }
            .clipShape(.rect(cornerRadius: SuiteRadius.medium))
            .accessibilityElement().accessibilityLabel("Crop frame \(shape)")
            .accessibilityValue(shape).accessibilityIdentifier("suite.gallery.crop.frame")
    }
}
