// HoverButtonStyle.swift: the hover and press look for a button that draws its
// own surface, such as the loupe's Grid pill over a photo. Hover adds the
// row-hover fill and an outline, so it never reads by fill alone; pressed
// takes the field fill. A disabled button dims and shows neither. The level
// is a pure function (HoverButtonLevel) so the rule is tested without a
// window. Owns presentation state only: hover.
import SwiftUI

/// The surface a floating button shows: nothing, hover, or pressed.
public enum HoverButtonLevel: Equatable, Sendable {
    case rest, hover, pressed

    /// Pressed wins over hover, and a disabled button always rests.
    public static func resolve(hovering: Bool, pressed: Bool, enabled: Bool = true) -> HoverButtonLevel {
        guard enabled else { return .rest }
        if pressed { return .pressed }
        return hovering ? .hover : .rest
    }

    /// The fill drawn over the button's own surface at this level.
    public var fill: Color? {
        switch self {
        case .rest: nil
        case .hover: SuiteColor.rowHover
        case .pressed: SuiteColor.field
        }
    }
}

public struct HoverButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(configuration: configuration)
    }

    private struct HoverButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.suiteReduceMotion) private var reduceMotion

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: SuiteRadius.large)
            let level = HoverButtonLevel.resolve(hovering: hovering, pressed: configuration.isPressed, enabled: isEnabled)
            configuration.label
                .overlay {
                    if let fill = level.fill { shape.fill(fill).allowsHitTesting(false) }
                }
                .overlay { if level != .rest { shape.strokeBorder(SuiteColor.outline, lineWidth: 1).allowsHitTesting(false) } }
                .contentShape(shape)
                .opacity(isEnabled ? 1 : SuiteColor.disabledOpacity)
                .onHover { hovering = $0 }
                .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: level)
        }
    }
}
