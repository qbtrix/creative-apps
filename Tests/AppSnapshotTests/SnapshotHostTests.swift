// SnapshotHostTests.swift: SnapshotHost draws at scale 2 (QB-V3, QB-S25) in
// the four appearances, and SuiteUI's glass stand-in draws inside it. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SnapshotHostTests {
    /// The pixel at (x, y) as [r, g, b, a].
    static func pixel(_ image: RGBAImage, _ x: Int, _ y: Int) -> [UInt8] {
        let at = (y * image.width + x) * 4
        guard x >= 0, y >= 0, x < image.width, y < image.height, at + 4 <= image.bytes.count else { return [] }
        return Array(image.bytes[at..<at + 4])
    }

    /// True when some channel of `a` and `b` differs by more than `limit`.
    static func differs(_ a: [UInt8], _ b: [UInt8], limit: Int = 2) -> Bool {
        a.count != b.count || zip(a, b).contains { abs(Int($0) - Int($1)) > limit }
    }

    /// `hex` (0xRRGGBB) as opaque [r, g, b, 255].
    static func rgba(_ hex: UInt32) -> [UInt8] {
        [UInt8(hex >> 16 & 0xFF), UInt8(hex >> 8 & 0xFF), UInt8(hex & 0xFF), 255]
    }

    @Test func scale() throws {
        for appearance in SnapshotAppearance.allCases {
            let host = SnapshotHost(appearance: appearance)
            let rep = try #require(host.render(Color.clear, size: CGSize(width: 100, height: 50)))
            #expect(rep.pixelsWide == 200 && rep.pixelsHigh == 100, "\(appearance.rawValue)")
            #expect(rep.size == CGSize(width: 100, height: 50))
            let image = try #require(host.image(Color.clear, size: CGSize(width: 100, height: 50)))
            #expect(image.width == 200 && image.height == 100)
        }
        #expect(SnapshotHost(appearance: .light).render(Color.clear, size: .zero) == nil)
    }

    /// QB-S25: a 1 pt hairline at x = 10 pt covers exactly pixels 20 and 21, at full color.
    @Test func hairline() throws {
        let view = HStack(spacing: 0) {
            Color.white.frame(width: 10)
            Rectangle().fill(SuiteColor.hairline).frame(width: 1)
            Color.white
        }
        let image = try #require(SnapshotHost(appearance: .light).image(view, size: CGSize(width: 40, height: 20)))
        let white: [UInt8] = [255, 255, 255, 255]
        let marked = (0..<image.width).filter { Self.differs(Self.pixel(image, $0, 20), white) }
        #expect(marked == [20, 21])
        let line = Self.rgba(SuitePalette.hairline.light)
        #expect(!Self.differs(Self.pixel(image, 20, 20), line) && !Self.differs(Self.pixel(image, 21, 20), line))
    }

    /// Each host resolves a dynamic token to its own appearance's value, the
    /// Increase Contrast ones included.
    @Test func appearances() throws {
        let token = SuitePalette.hairline
        #expect(Set(token.values).count == 4)
        for appearance in SnapshotAppearance.allCases {
            let image = try #require(SnapshotHost(appearance: appearance)
                .image(Rectangle().fill(SuiteColor.hairline), size: CGSize(width: 20, height: 20)))
            let center = Self.pixel(image, 20, 20)
            #expect(!Self.differs(center, Self.rgba(appearance.value(of: token))),
                    "\(appearance.rawValue) drew \(center)")
        }
    }

    /// The glass stand-in draws inside the host at scale 2: its fill differs
    /// from the background around it and its 1 pt border is 2 px.
    @Test func glassStandIn() throws {
        let glass = Color.clear.frame(width: 80, height: 30).suiteGlass(in: Rectangle()).padding(10)
        for appearance in SnapshotAppearance.allCases {
            let image = try #require(SnapshotHost(appearance: appearance)
                .image(glass, size: CGSize(width: 100, height: 50)))
            #expect(image.width == 200 && image.height == 100)
            let outside = Self.pixel(image, 4, 50), inside = Self.pixel(image, 100, 50)
            #expect(Self.differs(outside, inside), "\(appearance.rawValue): no stand-in fill")
            let border = (0..<60).filter {
                let p = Self.pixel(image, $0, 50)
                return Self.differs(p, outside) && Self.differs(p, inside)
            }
            #expect(border.count == 2, "\(appearance.rawValue): border at \(border)")
        }
    }

    /// The golden overload names its files by appearance.
    @Test func goldenNames() {
        #expect(SnapshotAppearance.allCases.map(\.rawValue) == ["light", "dark", "light-ic", "dark-ic"])
        #expect(SnapshotAppearance.lightContrast.scheme == .light && SnapshotAppearance.darkContrast.scheme == .dark)
        #expect(SnapshotAppearance.darkContrast.appearanceName == .accessibilityHighContrastDarkAqua)
    }
}
