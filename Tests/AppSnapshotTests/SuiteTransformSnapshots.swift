// SuiteTransformSnapshots.swift: the transform tools (transform-tools TT-4)
// in Light and Dark: the selection box turned 30° with its rows
// (suiteui-transform-handles), the box flipped with its turn negated
// (suiteui-transform-flipped), the rows after a typed width
// (suiteui-transform-rows), and several items' union box with Rotation
// "Mixed" (suiteui-transform-several), each -light and -dark. macOS only.
import Foundation
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteTransformSnapshots {
    private static let size = CGSize(width: 680, height: 340)

    private static func page(_ item: TransformBox, mixed: Bool = false) -> some View {
        let b = item.box
        return HStack(alignment: .top, spacing: SuiteSpacing.m) {
            ZStack(alignment: .topLeading) {
                SuiteColor.overlayPaper
                SelectionHandlesEditor(rect: CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height),
                                       degrees: item.degrees, zoom: 1, onResize: { _ in }, onRotate: { _ in }, onEnd: {})
            }
            .frame(width: 400, height: 300, alignment: .topLeading)
            TransformRows(selection: item, help: nil, flipHelp: nil, rotationMixed: mixed) { _ in }
                .frame(width: SuiteSize.inspectorWidth.ideal)
        }
        .padding(SuiteSpacing.m)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    private static let box = Rect(minX: 100, minY: 80, maxX: 300, maxY: 200)

    // The argument list spells its rects out: a static of this main-actor suite read there is an
    // async access the @Test macro's expansion can't await.
    @Test(arguments: [
        ("handles", TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200), degrees: 30), false),
        ("flipped", TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200), degrees: -30, flipX: true), false),
        ("rows", TransformBox(box: Rect(minX: 100, minY: 80, maxX: 340, maxY: 200)), false),
        ("several", TransformBox(box: Rect(minX: 60, minY: 60, maxX: 340, maxY: 240)), true),
    ])
    func transform(name: String, item: TransformBox, mixed: Bool) throws {
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for appearance in [SnapshotAppearance.light, .dark] {
            let host = SnapshotHost(appearance: appearance)
            let bitmap = try #require(host.render(Self.page(item, mixed: mixed), size: Self.size))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "suiteui-transform-\(name)-\(appearance.rawValue).png"))
        }
    }

    @Test func theTurnedBoxDrawsTurned() throws {
        let host = SnapshotHost(appearance: .light)
        let flat = try #require(host.image(Self.page(TransformBox(box: Self.box)), size: Self.size))
        let turned = try #require(host.image(Self.page(TransformBox(box: Self.box, degrees: 30)), size: Self.size))
        // The unturned top edge's 1 pt outline crosses (150, 80) plus the page's padding, device pixels
        // 2y - 1 and 2y at scale 2 (like CM-4's edges); turned 30° about the centre it moves off it.
        let x = Int((150 + SuiteSpacing.m) * 2), y = Int((80 + SuiteSpacing.m) * 2)
        let paper = SnapshotHostTests.pixel(flat, Int((SuiteSpacing.m + 4) * 2), Int((SuiteSpacing.m + 4) * 2))
        #expect(SnapshotHostTests.differs(SnapshotHostTests.pixel(flat, x, y), paper))
        #expect(SnapshotHostTests.differs(SnapshotHostTests.pixel(flat, x, y), SnapshotHostTests.pixel(turned, x, y)))
    }
}
