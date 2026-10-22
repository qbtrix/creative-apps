// SuiteTransformSnapshots.swift: the transform tools (transform-tools TT-4)
// in Light and Dark: the selection box turned 30° with its rows
// (suiteui-transform-handles), the box flipped with its turn negated and a
// corner notch that mirrors with it (suiteui-transform-flipped), the rows
// after a typed width (suiteui-transform-rows), and two turned items'
// outlines under their union box with Rotation "Mixed"
// (suiteui-transform-several), each -light and -dark. macOS only.
import Foundation
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteTransformSnapshots {
    private static let size = CGSize(width: 680, height: 340)

    /// The several snapshot's two items, turned differently; the page draws their union as the box.
    private static let parts = [
        TransformBox(box: Rect(minX: 80, minY: 80, maxX: 200, maxY: 170), degrees: 10),
        TransformBox(box: Rect(minX: 190, minY: 130, maxX: 320, maxY: 220), degrees: 20),
    ]

    /// A notch in the box's own top-left corner, through its matrix, so a mirror moves it to another corner.
    private static func notch(_ item: TransformBox) -> Path {
        let m = TransformRules.matrix(of: item)
        return outline([Point(x: 0, y: 0), Point(x: 0.3, y: 0), Point(x: 0, y: 0.4)].map(m.apply))
    }

    private static func outline(_ points: [Point]) -> Path {
        Path { path in
            path.addLines(points.map { CGPoint(x: $0.x, y: $0.y) })
            path.closeSubpath()
        }
    }

    private static func page(_ given: TransformBox, mixed: Bool = false, mark: Bool = false,
                             parts: [TransformBox] = []) -> some View {
        let union = Rect(enclosing: parts.flatMap { TransformRules.corners(of: $0) }).map { TransformBox(box: $0) }
        let item = union ?? given
        let b = item.box
        return HStack(alignment: .top, spacing: SuiteSpacing.m) {
            ZStack(alignment: .topLeading) {
                SuiteColor.overlayPaper
                ForEach(parts.indices, id: \.self) { i in
                    outline(TransformRules.corners(of: parts[i])).stroke(SuiteColor.secondaryText, lineWidth: 1)
                }
                if mark { notch(item).fill(SuiteColor.accent) }
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
            let page = Self.page(item, mixed: mixed, mark: name == "flipped", parts: name == "several" ? Self.parts : [])
            let bitmap = try #require(host.render(page, size: Self.size))
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

    /// #4629: the flipped snapshot's notch sits in another corner than the unflipped box's, so the mirror shows.
    @Test func theFlippedMarkMirrors() throws {
        let host = SnapshotHost(appearance: .light)
        let plain = TransformBox(box: Self.box, degrees: -30), flipped = TransformBox(box: Self.box, degrees: -30, flipX: true)
        let a = try #require(host.image(Self.page(plain, mark: true), size: Self.size))
        let b = try #require(host.image(Self.page(flipped, mark: true), size: Self.size))
        let inside = TransformRules.matrix(of: plain).apply(Point(x: 0.08, y: 0.1))
        let (x, y) = (Int((inside.x + SuiteSpacing.m) * 2), Int((inside.y + SuiteSpacing.m) * 2))
        #expect(SnapshotHostTests.differs(SnapshotHostTests.pixel(a, x, y), SnapshotHostTests.pixel(b, x, y)))
    }
}
