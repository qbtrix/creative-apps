// PlaceDrop.swift: the drop target that places images (placed-images PL-2 placeholder; PL-3 takes file URLs and
// pasteboard image or SVG data, highlights only for items it can take and reads them off the main actor). Until then
// the view is returned as it is and takes no drop.
import SuiteKernel
import SwiftUI

extension View {
    /// Files and image or SVG data dropped from Finder or another app; `onPlace` gets each with the drop point.
    public func placeDropTarget(
        formats: Set<PlacedFormat>, onPlace: @escaping @MainActor ([(name: String, data: Data)], CGPoint) -> Bool
    ) -> some View {
        self
    }
}
