// SuiteAppSwitcherSnapshots.swift: the app switcher row (AppSwitcher) with
// Design current, in Light and Dark. Writes suiteui-app-switcher-light.png and
// suiteui-app-switcher-dark.png for review. Then a pixel check that the glass
// capsule draws only behind the current item: the row drawn with Design
// current differs from the row with no current item only inside Design's cell
// (the capsule overhangs the 80 pt cell by 5 pt a side; 2 more for its rim),
// and it differs there beside the icon too, so the capsule was drawn at all.
// macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func suiteAppSwitcher() throws {
    let state = AppSwitcherState.placeholder(processName: "DesignApp")
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(
            AppSwitcher(items: state.items, current: "design", onSelect: { _ in }),
            name: "suiteui-app-switcher-\(scheme.name)", scheme: scheme)
    }
}

@MainActor
@Test func theCapsuleDrawsOnlyBehindTheCurrentItem() throws {
    let items = AppSwitcherState.placeholder(processName: "xctest").items
    let spacing = SuiteSize.switcherSpacing
    // Exactly the row at the default 80 pt spacing, so item i spans [80i, 80i + 80].
    let size = CGSize(width: spacing * CGFloat(items.count), height: SuiteSize.switcherCapsule.height)
    let index = try #require(items.firstIndex { $0.id == "design" })
    let center = spacing * (CGFloat(index) + 0.5)
    let overhang = (SuiteSize.switcherCapsule.width - spacing) / 2 + 2
    for appearance in [SnapshotAppearance.light, .dark] {
        let host = SnapshotHost(appearance: appearance)
        let current = try #require(host.render(AppSwitcher(items: items, current: "design", onSelect: { _ in }), size: size))
        let none = try #require(host.render(AppSwitcher(items: items, current: nil, onSelect: { _ in }), size: size))
        var outside = 0
        var besideIcon = 0
        for y in 0..<current.pixelsHigh {
            for x in 0..<current.pixelsWide where differs(current, none, x, y) {
                let point = abs(CGFloat(x) / SnapshotHost.scale - center)
                if point > spacing / 2 + overhang {
                    outside += 1
                } else if point > SuiteSize.switcherIcon {
                    besideIcon += 1
                }
            }
        }
        #expect(outside == 0, "\(outside) px changed outside Design's item in \(appearance)")
        #expect(besideIcon > 0, "no capsule beside Design's icon in \(appearance)")
    }
}

/// Whether two renders' pixels at (x, y) differ by more than antialiasing noise.
@MainActor
private func differs(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep, _ x: Int, _ y: Int) -> Bool {
    guard let p = a.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
          let q = b.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
    else { return false }
    let distance = abs(p.redComponent - q.redComponent) + abs(p.greenComponent - q.greenComponent)
        + abs(p.blueComponent - q.blueComponent)
    return distance > 0.02
}
