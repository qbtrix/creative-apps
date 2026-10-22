// SuiteAreaSelectSnapshots.swift (area-selection AR-7): suite-gallery-area-select-{light,dark}.png, the options bar in
// each of the four modes and the ants on a lasso with a polygon in progress. macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteAreaSelectSnapshots {
    @Test func screens() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryAreaSelectSheet(), name: "suite-gallery-area-select-\(scheme.name)", scheme: scheme)
        }
    }
}
