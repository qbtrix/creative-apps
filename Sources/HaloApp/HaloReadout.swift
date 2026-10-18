// HaloReadout.swift: a value a journey reads, as the label of a hidden
// element. XCUITest reads SwiftUI accessibility values as empty strings
// (#262): a timeline lane's key count read "" on CI (run 38767265986), so
// each lane also publishes its text as the label of a 1 × 1 pt element,
// `halo.timeline.keys`, the way `halo.file` carries the save status. SuiteUI's
// ProbeElement draws it at HaloReadout.size: no hits and nothing drawn, so the
// app audit finds no control in it and too few pixels to measure as text. The real value stays on its
// element for VoiceOver.
import SwiftUI

/// The readout element's size, for SuiteUI's ProbeElement.
enum HaloReadout {
    /// Not a design size, since it draws nothing; under the audit's 16 pixels
    /// at 2x, so the contrast check never measures it as text.
    static let size = CGSize(width: 1, height: 1)
}
