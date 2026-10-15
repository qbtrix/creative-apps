// HaloTimelineHelp.swift: what the timeline's tooltip says and what a click
// on a key diamond does. The ruler counts frames while the status bar and
// inspector speak in seconds, so the help names the unit and the frame rate,
// the span bar and the diamonds. Until key picking works a diamond's click
// selects its layer instead, and the help says why. Linux-safe.

extension HaloComposition {
    /// The timeline's tooltip: the ruler's unit, the bar, the diamonds, the
    /// ruler drag and the I and O keys.
    public var timelineHelp: String {
        "The ruler counts frames (\(max(0, framesPerSecond)) per second). " + HaloProject.timelineHelpTail
    }
}

extension HaloProject {
    /// What every timeline tooltip ends with, after the ruler's unit.
    static let timelineHelpTail = "Each bar runs from a layer's in point to its out point; diamonds are its keys. "
        + "Drag the ruler to move the playhead. I sets the selected layer's in point, O its out point."

    /// The selected composition's timeline help, plus why keys can't be
    /// picked yet while they can't.
    public var timelineHelp: String {
        let base = selectedComposition?.timelineHelp ?? "The ruler counts frames. " + Self.timelineHelpTail
        guard let reason = unavailableHelp(for: .selectLaneKeys(layerID: "", frame: 0, extending: false)) else {
            return base
        }
        return base + " Clicking a key selects its layer; picking keys: \(reason)"
    }

    /// The command a click on `layerID`'s key at `frame` sends: pick that
    /// lane's keys, or select the layer while key picking can't act.
    public func keyClickCommand(layerID: String, frame: Int) -> HaloCommand {
        let pick = HaloCommand.selectLaneKeys(layerID: layerID, frame: frame, extending: false)
        return unavailableHelp(for: pick) == nil ? pick : .selectLayer(layerID)
    }
}
