// ShellGeometry.swift: the window shell's geometry rules
// (docs/blueprints/suiteui/features/editor-in-window.md, EW-4). Given the
// frames a journey reads (UITests/Journey+Geometry.swift), it lists what is
// wrong: a region outside the window, two columns overlapping by more than a
// hairline, a region under its minimum size, or a palette over a ruler or a
// grown artboard. Each violation names both regions, or the region and the
// window.
//
// It lives in the AppAuditTests target, which builds and tests on Linux;
// project.yml compiles it into every UI journey bundle. Plain Swift and
// Foundation, on AppAudit.Rect (AuditPixels.swift): origin top left, points.
import Foundation

enum ShellGeometry {
    typealias Rect = AppAudit.Rect

    /// How far two `apart` regions may overlap: a 1 pt hairline is allowed.
    static let hairline = 1.0
    /// Rounding slack for frames a window server reports as fractions.
    static let slack = 0.01

    /// Every violation of the rules, in a stable order: containment, then
    /// minimums, then `apart` and `clear` pairs as given. `container` names
    /// `window` in the messages (a journey passes "visible frame" when it
    /// checks the window against the display).
    static func violations(
        window: Rect, regions: [String: Rect], minimums: [String: (width: Double, height: Double)],
        apart: [(String, String)], clear: [(String, String)], container: String = "window"
    ) -> [String] {
        var found: [String] = []
        for (name, region) in regions.sorted(by: { $0.key < $1.key }) {
            let outside = max(window.x - region.x, region.maxX - window.maxX, window.y - region.y, region.maxY - window.maxY)
            if outside > slack {
                found.append("\(name) \(describe(region)) is \(points(outside)) pt outside the \(container) \(describe(window))")
            }
        }
        for (name, minimum) in minimums.sorted(by: { $0.key < $1.key }) {
            guard let region = regions[name] else {
                found.append("\(name) is missing (minimum \(points(minimum.width)) × \(points(minimum.height)))")
                continue
            }
            if region.width < minimum.width - slack || region.height < minimum.height - slack {
                found.append(
                    "\(name) is \(points(region.width)) × \(points(region.height)) pt, under its minimum "
                        + "\(points(minimum.width)) × \(points(minimum.height)) in the \(container)")
            }
        }
        for (first, second) in apart {
            guard let a = regions[first], let b = regions[second] else {
                found.append(missing(first, second, in: regions))
                continue
            }
            let (width, height) = overlap(a, b)
            let depth = min(width, height)
            if width > 0, height > 0, depth > hairline + slack {
                found.append("\(first) and \(second) overlap by \(points(depth)) pt (at most \(points(hairline)))")
            }
        }
        for (first, second) in clear {
            guard let a = regions[first], let b = regions[second] else {
                found.append(missing(first, second, in: regions))
                continue
            }
            let (width, height) = overlap(a, b)
            if width > slack, height > slack {
                found.append("\(first) \(describe(a)) is over \(second) \(describe(b))")
            }
        }
        return found
    }

    /// The width and height two rectangles share; zero or less when they don't meet.
    private static func overlap(_ a: Rect, _ b: Rect) -> (width: Double, height: Double) {
        (min(a.maxX, b.maxX) - max(a.x, b.x), min(a.maxY, b.maxY) - max(a.y, b.y))
    }

    private static func missing(_ first: String, _ second: String, in regions: [String: Rect]) -> String {
        let absent = [first, second].filter { regions[$0] == nil }.joined(separator: " and ")
        return "\(absent) \(absent.contains(" and ") ? "are" : "is") missing (\(first)–\(second))"
    }

    private static func describe(_ r: Rect) -> String {
        "(\(points(r.x)), \(points(r.y)), \(points(r.width)) × \(points(r.height)))"
    }

    /// 220 prints "220", 739.5 prints "739.5".
    private static func points(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
