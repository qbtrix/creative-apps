// HaloJourneyTests+Readouts.swift: each timeline lane's key count, which
// XCUITest reads empty as the lane's value (#262), read instead from its
// hidden `halo.timeline.keys` readout (Sources/HaloApp/HaloReadout.swift),
// labelled "Ball: 3 keyframes". The artboard's and canvas's summaries have
// their own labelled leaves (`halo.viewer.summary`, `halo.viewer.drawn`).
import XCTest

extension Journey {
    /// What each lane of `layer` reads ("3 keyframes"), from `halo.timeline.keys`.
    func laneKeys(_ layer: String) -> [String] {
        let prefix = "\(layer): "
        return app.descendants(matching: .any).matching(identifier: "halo.timeline.keys").allElementsBoundByIndex
            .map(\.label).filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
}
