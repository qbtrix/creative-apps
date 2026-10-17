// FlareStatusRead.swift: the status pills under the stage (packet inspector-timeline, IT-9), read off the
// workspace so Linux tests cover them; FlareTransport only draws them in a ViewerStatusBar. The scene's aspect
// ("16:9", reduced by the greatest common divisor), its size ("1080p" for a 16:9 or 9:16 scene, named by its short
// side, else "550 × 400"), its rate ("24 fps"), and while playing the rate the screen actually shows: the display
// link's ticks over the last second (`PlaybackDriver.measuredFPS`), capped at the document rate, since a 60 Hz link
// still shows each of 24 frames once. Under the document rate it is dropping (QB-L4, report-only). A scene with text
// the stage can't draw says so: "Text not shown (1)". Integer math on clamped values, so nothing here can trap.
import FlareCore

extension FlareWorkspace {
    /// The pills for the selected scene; `measuredFPS` is the driver's measure while playing, nil before it has one.
    public func statusPills(measuredFPS: Double?) -> StatusPills {
        guard let scene = selectedScene else { return StatusPills(aspect: "–", size: "–", fps: "–") }
        let width = Self.side(scene.width), height = Self.side(scene.height)
        var pills = StatusPills(
            aspect: Self.aspectText(width, height), size: Self.sizeText(width, height), fps: "\(scene.fps) fps")
        if isPlaying, scene.fps > 0, let measuredFPS, measuredFPS.isFinite, measuredFPS > 0 {
            let shown = min(Int(min(measuredFPS, 1_000).rounded()), scene.fps)
            pills.actualFPS = "\(shown) fps"
            pills.isDropping = shown < scene.fps
        }
        if let hidden = stageList?.hiddenTextCount, hidden > 0 { pills.textWarning = "Text not shown (\(hidden))" }
        return pills
    }

    /// A side in whole points, 0 when it isn't finite or positive, clamped so it fits an Int.
    static func side(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        return Int(min(value, 1_000_000).rounded())
    }

    /// "16:9": the sides over their greatest common divisor; "–" when a side is 0.
    static func aspectText(_ width: Int, _ height: Int) -> String {
        guard width > 0, height > 0 else { return "–" }
        var a = width, b = height
        while b != 0 { (a, b) = (b, a % b) }
        return "\(width / a):\(height / a)"
    }

    /// "1080p" for a 16:9 or 9:16 scene, named by its short side; otherwise "550 × 400".
    static func sizeText(_ width: Int, _ height: Int) -> String {
        let aspect = aspectText(width, height)
        return aspect == "16:9" || aspect == "9:16" ? "\(min(width, height))p" : "\(width) × \(height)"
    }
}

/// The status bar's pills: the scene's aspect, size and rate, the rate actually shown while playing, and a warning
/// when the stage leaves text out.
public struct StatusPills: Sendable, Equatable {
    public var aspect: String, size: String, fps: String    // "16:9", "1080p", "24 fps"
    public var actualFPS: String?, isDropping: Bool         // while playing
    public var textWarning: String?                         // "Text not shown (1)"

    public init(
        aspect: String, size: String, fps: String, actualFPS: String? = nil, isDropping: Bool = false,
        textWarning: String? = nil
    ) {
        self.aspect = aspect; self.size = size; self.fps = fps
        self.actualFPS = actualFPS; self.isDropping = isDropping; self.textWarning = textWarning
    }
}
