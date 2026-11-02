// PhotoRendering.swift: View > Rendering for Photo (render-backend adoption
// R1). One per app process: the suite's live RenderingPreference (one key
// every suite app shares, so the choice survives a relaunch) and the Metal
// backend on the system GPU (SuiteImaging's ImagingGPU), made on the first
// route that wants it, its
// pipelines compiling in the background (until a family lands the dispatcher
// draws it on the CPU). `route` turns the choice into a PhotoRenderRoute: CPU
// draws on the CPU; Automatic and GPU prefer Metal while a device exists and
// the backend is healthy, else the CPU. PhotoApp puts the shared one in the
// environment, so a window follows it and a test's window (no environment)
// stays on the CPU. macOS only.
import CoreRender
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI

@MainActor final class PhotoRendering {
    /// The app's: the suite's shared defaults and the system GPU.
    static let shared = PhotoRendering(preference: RenderingPreference(suiteName: RenderingPreference.suiteName))

    let preference: any RenderingPreferenceReading
    private let makeGPU: @MainActor () -> (any RenderBackend)?
    private var gpu: (any RenderBackend)??

    /// Over `preference`; `makeGPU` opens the GPU backend the first time a route asks for it.
    init(preference: any RenderingPreferenceReading,
         makeGPU: @escaping @MainActor () -> (any RenderBackend)? = PhotoRendering.systemGPU) {
        self.preference = preference
        self.makeGPU = makeGPU
    }

    /// The route the current choice draws on.
    var route: PhotoRenderRoute {
        guard preference.choice != .cpu else { return .cpu }
        if gpu == nil { gpu = makeGPU() }
        return Self.route(preference.choice, gpu: gpu ?? nil)
    }

    /// CPU draws on the CPU; Automatic and GPU on `gpu` while it is healthy, else the CPU.
    nonisolated static func route(_ choice: RenderingChoice, gpu: (any RenderBackend)?) -> PhotoRenderRoute {
        guard choice != .cpu, let gpu, gpu.isHealthy else { return .cpu }
        return PhotoRenderRoute(preferred: gpu)
    }

    /// The Metal backend on the system GPU, compiling in the background; nil without a GPU.
    static func systemGPU() -> (any RenderBackend)? {
        ImagingGPU.systemBackend()?.renderBackend
    }
}

extension EnvironmentValues {
    /// The app's View > Rendering; nil (the CPU) outside the app, as in tests.
    var photoRendering: PhotoRendering? {
        get { self[PhotoRenderingKey.self] }
        set { self[PhotoRenderingKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as PhotoMenuKey.
private struct PhotoRenderingKey: EnvironmentKey {
    static let defaultValue: PhotoRendering? = nil
}
