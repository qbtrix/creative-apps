// SnapshotHost.swift: the golden host (QH-2b, #332). Hosts a SwiftUI view in
// an NSHostingView inside an offscreen borderless window with one of the four
// appearances (Light, Dark, Light + Increase Contrast, Dark + Increase
// Contrast), set on both the window and the hosting view so AppKit's
// appearance decides how dynamic colors resolve, and draws it at backing
// scale 2, so a 100 × 50 pt view is a 200 × 100 px image and a 1 pt hairline is 2 device pixels (QB-V3). The
// bitmap is tagged sRGB, so a token's hex comes back as written. Glass draws
// as SuiteUI's flat stand-in (`suiteSnapshotRendering`). Its images feed
// GoldenImage (SH-9) through `assertGolden(_:size:name:area:appearance:)`.
// macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

/// The four appearances a SuiteUI component is recorded in (QB-V5).
enum SnapshotAppearance: String, CaseIterable, Sendable {
    case light
    case dark
    case lightContrast = "light-ic"
    case darkContrast = "dark-ic"

    var appearanceName: NSAppearance.Name {
        switch self {
        case .light: .aqua
        case .dark: .darkAqua
        case .lightContrast: .accessibilityHighContrastAqua
        case .darkContrast: .accessibilityHighContrastDarkAqua
        }
    }

    var scheme: ColorScheme { self == .dark || self == .darkContrast ? .dark : .light }

    /// Increased for the two Increase Contrast appearances. SwiftUI takes the
    /// `colorSchemeContrast` views read from the system setting, not the
    /// window's appearance, so the host sets it in the environment (the
    /// underscored setter; the public one is read-only). It always agrees with
    /// `appearanceName`, which alone decides how NSColor tokens resolve.
    var contrast: ColorSchemeContrast { self == .lightContrast || self == .darkContrast ? .increased : .standard }

    /// The token value SuiteHex documents for this appearance.
    func value(of hex: SuiteHex) -> UInt32 {
        switch self {
        case .light: hex.light
        case .dark: hex.dark
        case .lightContrast: hex.lightContrast
        case .darkContrast: hex.darkContrast
        }
    }
}

/// An offscreen window that reports backing scale 2 on any screen, so views
/// that size their layers by the window's scale rasterize at 2× on a 1× CI
/// display too. SnapshotHostTests.hairline catches a blurred upscale.
private final class ScaledSnapshotWindow: NSWindow {
    override var backingScaleFactor: CGFloat { SnapshotHost.scale }
}

/// Renders views at scale 2 in one appearance.
@MainActor
struct SnapshotHost {
    nonisolated static let scale: CGFloat = 2
    let appearance: SnapshotAppearance

    /// `view` at `size` points over the window background, as a 2× bitmap; nil
    /// when the size is empty or AppKit has no such appearance.
    func render(_ view: some View, size: CGSize) -> NSBitmapImageRep? {
        let pixelsWide = Int((size.width * Self.scale).rounded())
        let pixelsHigh = Int((size.height * Self.scale).rounded())
        guard pixelsWide > 0, pixelsHigh > 0, let named = NSAppearance(named: appearance.appearanceName) else {
            return nil
        }
        let host = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height)
            .background(SuiteColor.windowBackground)
            .environment(\.suiteSnapshotRendering, true)
            .environment(\._colorSchemeContrast, appearance.contrast))
        // No colorScheme override: SwiftUI derives the scheme from the
        // effective NSAppearance, and forcing it made SwiftUI resolve NSColor
        // tokens against a plain aqua/darkAqua appearance, dropping the
        // Increase Contrast name. The appearance goes on the view as well as
        // the window so it holds before the view joins the window.
        host.appearance = named
        host.frame = CGRect(origin: .zero, size: size)
        let window = ScaledSnapshotWindow(
            contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = named
        window.contentView = host
        // Two layout passes around a short run loop turn, so lists and scroll views settle.
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        guard let blank = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0),
            let image = blank.retagging(with: .sRGB)
        else { return nil }
        // Points in, pixels out: the size in points over twice the pixels is the 2× scale.
        image.size = size
        host.cacheDisplay(in: host.bounds, to: image)
        return image
    }

    /// `render(_:size:)` as 8-bit sRGB RGBA, top row first: what GoldenImage compares.
    func image(_ view: some View, size: CGSize) -> RGBAImage? {
        render(view, size: size)?.cgImage.flatMap(RGBAImage.init(cgImage:))
    }
}

/// Renders `view` at `size` points through SnapshotHost and checks it as
/// `Golden/<area>/<name>-<appearance>.png` (light, dark, light-ic, dark-ic).
@MainActor
func assertGolden(_ view: some View, size: CGSize, name: String, area: String, appearance: SnapshotAppearance,
                  tolerance: GoldenTolerance = .standard, filePath: String = #filePath,
                  sourceLocation: SourceLocation = #_sourceLocation) {
    guard let image = SnapshotHost(appearance: appearance).image(view, size: size) else {
        Issue.record("could not render \(area)/\(name)-\(appearance.rawValue)", sourceLocation: sourceLocation)
        return
    }
    assertGolden(image, name: name, area: area, appearance: appearance.rawValue,
                 tolerance: tolerance, filePath: filePath, sourceLocation: sourceLocation)
}
