// StageRasterizerAdapter.swift: FrameRasterizing on the suite's one vector rasterizer (#5079;
// docs/blueprints/flare/features/flare-export.md, FX-7). `StageRasterizer` hands a StageDrawList to SuiteShell's
// VectorRasterizer: the scene's size and background (none when `transparent`), and every non-text item in paint
// order with its path, fill, stroke, stroke path, matrix and opacity. The drawing, the size checks and the PNG are
// VectorRasterizer's, so its errors are this one's (`RasterizerError`).
import FlareCore
import FlareModel
import Foundation
import SuiteShell

typealias RasterizerError = VectorRasterError

struct StageRasterizer: FrameRasterizing {
    init() {}

    func png(_ list: StageDrawList, scale: Double, transparent: Bool) throws -> Data {
        try VectorRasterizer().png(Self.vector(list, transparent: transparent), scale: scale)
    }

    /// `list` as the shared draw list; text items are left out, as the stage leaves them.
    static func vector(_ list: StageDrawList, transparent: Bool) -> VectorDrawList {
        VectorDrawList(width: list.width, height: list.height, background: transparent ? nil : list.background,
                       items: list.items.filter { !$0.isText }.map {
                           VectorDrawItem(path: $0.path, fill: $0.fill, stroke: $0.stroke, strokePath: $0.strokePath,
                                          transform: $0.transform, opacity: $0.opacity)
                       })
    }
}
