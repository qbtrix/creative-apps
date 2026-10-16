// FlareWindow+File.swift: the router's file area (FlareWindow+Router.swift).
// New makes an empty document; every other file intent (open, save, recent,
// close) waits for F17a's panels (DK-12) and says so.
import FlareModel

extension FlareWindow {
    /// Acts on a file intent: New only, for now.
    func performFile(_ intent: FlareIntent.File) {
        switch intent {
        case .new: model.newDocument()
        default: break
        }
    }

    /// Why a file intent can't act now; nil for New.
    func fileHelp(_ intent: FlareIntent.File) -> String? {
        switch intent {
        case .new: nil
        default: "Not built yet (F17a)."
        }
    }
}
