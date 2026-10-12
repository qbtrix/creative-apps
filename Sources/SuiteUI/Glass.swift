// Glass.swift: the one place SuiteUI applies Liquid Glass. Components call
// `suiteGlass(in:)` instead of `.glassEffect` directly. Normally that is system
// glass. With `suiteSnapshotRendering` set in the environment it draws a flat,
// bordered stand-in instead, because ImageRenderer drops glass views from the
// image entirely, content and all; AppSnapshotTests sets it so palettes and
// panels still show up in the PNGs.
import SwiftUI

extension EnvironmentValues {
    /// True while rendering snapshots: glass draws as a flat stand-in.
    @Entry public var suiteSnapshotRendering = false
}

extension View {
    func suiteGlass(in shape: some Shape) -> some View {
        modifier(SuiteGlass(shape: shape))
    }
}

private struct SuiteGlass<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.suiteSnapshotRendering) private var snapshot

    func body(content: Content) -> some View {
        if snapshot {
            content
                .background(SuiteColor.surface.opacity(0.92), in: shape)
                .overlay(shape.stroke(SuiteColor.separator, lineWidth: 1))
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}
