// SuiteShapeToolsSnapshots.swift (shape-tools SH-4): ShapeToolOptions in an
// inspector-width panel, in Light and Dark. The chips with Star's rows
// (Points 5, Inner ratio 50%), Polygon's Sides, Rectangle's Corner radius,
// Arrow's Head, and Sides refused at 2 with the range under it. Writes
// suiteui-shape-tools{,-polygon,-rectangle,-arrow,-help}-{light,dark}.png.
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteShapeToolsSnapshots {
    @Test func shapeToolStates() throws {
        let help = ShapeToolOptions.change(.sides, typed: 2, spec: .defaults(.polygon)).help
        let states: [(String, ShapeKind, (ShapeOptionRow.Field, String)?)] = [
            ("", .star, nil), ("-polygon", .polygon, nil), ("-rectangle", .rectangle, nil), ("-arrow", .arrow, nil),
            ("-help", .polygon, help.map { (.sides, $0) }),
        ]
        #expect(help != nil, "a typed 2 in Sides has no help to show")
        for (suffix, kind, refused) in states {
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(
                    ShapeToolsSample(kind: kind, refused: refused),
                    name: "suiteui-shape-tools\(suffix)-\(scheme.name)", scheme: scheme)
            }
        }
    }
}

private struct ShapeToolsSample: View {
    let kind: ShapeKind
    let refused: (ShapeOptionRow.Field, String)?

    var body: some View {
        ShapeToolOptions(spec: .defaults(kind), help: nil, refused: refused) { _ in }
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
            .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
