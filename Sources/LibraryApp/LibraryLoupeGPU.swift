// LibraryLoupeGPU.swift: the loupe's GPU route (suite-imaging IM-11). A
// GPU frame's decoded base is uploaded once per photo and size and kept on
// the GPU; each develop step then writes the base through the frame's program
// and the screen's display step straight into the canvas host's resident
// texture (`ImagingGPU.display`): no CPU pass, no readback. View > Rendering
// set to CPU, no GPU, pipelines still compiling or a failed write keep the CPU
// route; a failure hands the loupe back to it (`onFailure`) for the session.
// The window's environment carries the app's one instance; a test window
// gets none, so it stays on the CPU route.
import CoreRaster
import CoreRender
import LibraryModel
import SuiteImaging
import SuiteUI
import SwiftUI

@MainActor final class LibraryLoupeGPU {
    /// The app's: the suite's shared rendering choice and the system GPU.
    static let shared = LibraryLoupeGPU(preference: RenderingPreference(suiteName: RenderingPreference.suiteName))

    let preference: any RenderingPreferenceReading
    /// Called once a GPU write fails, so the loupe draws its picture on the CPU.
    var onFailure: @MainActor () -> Void = {}
    private var backend: ImagingGPU.Backend??
    /// The base on the GPU, keyed by photo and size, so an 8K photo uploads once.
    private var resident: (key: String, surface: ImagingGPU.Surface)?
    /// The view and the token last written, so a SwiftUI update doesn't redraw.
    private weak var view: CanvasHostView?
    private var drawn: Int?
    private var failed = false

    init(preference: any RenderingPreferenceReading) { self.preference = preference }

    /// Whether the loupe asks for GPU frames: a choice other than CPU, a
    /// healthy backend with its display pipelines compiled, no failure yet.
    var prefersGPU: Bool {
        guard preference.choice != .cpu, !failed else { return false }
        if backend == nil { backend = ImagingGPU.systemBackend() }
        guard let gpu = backend ?? nil else { return false }
        return gpu.isHealthy && gpu.isReady
    }

    /// `image` through `program` into `view`'s resident texture, once per token.
    func draw(_ image: DisplayImage, program: [ToneProgram.Operation], token: Int, photoID: String?, into view: CanvasHostView) {
        guard self.view !== view || drawn != token else { return }
        (self.view, drawn) = (view, token)
        let width = image.size.width, height = image.size.height
        view.show(Shown(width: width, height: height))
        do {
            guard let gpu = backend ?? nil, let presenter = view.metalPresenter as? CanvasTilePresenter,
                  let texture = presenter.residentTexture(on: gpu.device, width: width, height: height)
            else { throw LibraryError.renderFailed("the GPU route isn't available") }
            let key = "\(photoID ?? "")/\(width)x\(height)"
            if resident?.key != key {
                resident = nil
                resident = (key, try gpu.upload(PixelBuffer(rgba8: image.rgba8, width: width, height: height)))
            }
            guard let surface = resident?.surface else { return }
            try ImagingGPU.display(surface, into: texture, program: program,
                                   displaySteps: ImagingColor.displaySteps(to: .sRGB))
            view.show(Shown(width: width, height: height))
        } catch {
            (failed, drawn, resident) = (true, nil, nil)
            onFailure()
        }
    }

    /// The picture's size with no tiles: the texture holds the pixels.
    struct Shown: CanvasContentProviding {
        let width: Int, height: Int
        var documentSize: CGSize { CGSize(width: width, height: height) }
        func tiles(dirtyOnly: Bool) -> [CanvasTile] { [] }
    }
}

extension EnvironmentValues {
    /// The loupe's GPU route; nil (a test window) keeps the CPU route.
    @Entry var libraryLoupeGPU: LibraryLoupeGPU? = nil
}
