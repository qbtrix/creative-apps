// CropAspectChoices.swift (orientation-crop OC-5): the crop aspect picker's rules, here so Linux tests them: the chips
// and their crop.* command, when the toggle (X, crop.swap) acts, a custom W:H or why not, and the frame a pick gives.

/// One chip of the crop aspect picker, in the order it shows.
public enum CropAspectChoice: String, CaseIterable, Hashable, Sendable, Identifiable {
    case free = "Free", original = "Original", square = "1:1", fourFive = "4:5", threeTwo = "3:2", sixteenNine = "16:9", custom = "Custom"

    public var id: Self { self }; public var title: String { rawValue }
    public var identifier: String { "suite.crop.aspect-" + String(rawValue.lowercased().map { $0 == ":" ? "-" : $0 }) }
    public var command: String { CropAspectChoices.aspectCommand }
    /// The aspect the chip locks to; nil for Custom, whose fields give it.
    public var aspect: CropAspect? { self == .custom ? nil : CropAspect(rawValue: rawValue) }

    /// The chip that shows `aspect`: its preset, or Custom.
    public static func chip(for aspect: CropAspect) -> CropAspectChoice {
        allCases.first { $0.aspect == aspect } ?? .custom
    }
}

/// A choice in the picker: the command it runs and the aspect and orientation it carries.
public struct CropPick: Hashable, Sendable {
    public var command: String, aspect: CropAspect, orientation: CropOrientation
    public init(command: String, aspect: CropAspect, orientation: CropOrientation) {
        (self.command, self.aspect, self.orientation) = (command, aspect, orientation)
    }
}

/// A custom W:H as typed: the aspect, or the sentence that says why not.
public enum CropCustomRatio: Hashable, Sendable {
    case aspect(CropAspect), problem(String)
}

public enum CropAspectChoices {
    public static let aspectCommand = "crop.set-aspect", swapCommand = "crop.swap"
    public static let largestSide = 1000

    /// Why the orientation toggle can't act on `aspect`; nil when it can.
    public static func swapHelp(_ aspect: CropAspect) -> String? {
        switch aspect {
        case .free: "Free has no shape to turn: pick a ratio first."
        case .ratio(let w, let h) where w == h: "A square is the same either way."
        case .original, .ratio: nil
        }
    }

    /// The custom fields' W:H: whole numbers from 1 to `largestSide`, or a sentence for anything else.
    public static func custom(width: String, height: String) -> CropCustomRatio {
        let (w, h) = (trimmed(width), trimmed(height))
        guard !w.isEmpty, !h.isEmpty else { return .problem("Type a width and a height, like 7 and 3.") }
        guard let wide = Int(w), let tall = Int(h) else { return .problem("Width and height are whole numbers, like 7 and 3.") }
        guard wide >= 1, tall >= 1 else { return .problem("Width and height must be at least 1.") }
        guard wide <= largestSide, tall <= largestSide else { return .problem("Width and height go up to \(largestSide).") }
        return .aspect(.ratio(width: wide, height: tall))
    }

    private static func trimmed(_ text: String) -> String {
        String(text.drop { $0.isWhitespace }.reversed().drop { $0.isWhitespace }.reversed())
    }

    /// The way a typed ratio stands: wider than tall is landscape, taller portrait, a square keeps `current`.
    public static func orientation(of aspect: CropAspect, else current: CropOrientation) -> CropOrientation {
        guard case .ratio(let w, let h) = aspect, w != h else { return current }
        return w > h ? .landscape : .portrait
    }

    /// The largest frame of `aspect` standing `orientation` in `bounds`; Original turns too, as crop.swap turns it.
    public static func frame(_ aspect: CropAspect, _ orientation: CropOrientation, in bounds: Rect) -> Rect {
        let rect = CropRules.largest(aspect, orientation: orientation, in: bounds)
        guard aspect == .original, rect.width != rect.height, (rect.height > rect.width) != (orientation == .portrait) else { return rect }
        return CropRules.swapped(rect, in: bounds)
    }

    /// "crop.set-aspect 4:5 portrait"
    public static func line(_ pick: CropPick) -> String {
        "\(pick.command) \(pick.aspect.rawValue) \(pick.orientation.rawValue)"
    }
}
