// PhotoLayered+Imaging.swift: opening a layered file (CoreRaster's
// LayeredImage, as PSD.read returns it) as a Photo workspace (psd-effects).
// The contract the PSD route plugs into; a stub that refuses until PS-3 builds
// the body: layers back to front with masks, clipping and styles, groups, and
// a warning naming everything the file held that the workspace can't keep.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

extension PhotoWorkspace {
    /// The workspace for a layered file: layers back to front with masks, clipping and styles; `warnings` names
    /// every drop (core's notes plus StyleProgram.style's `dropped`), "<layer>: <what> (not kept)".
    public static func opening(_ image: LayeredImage) throws -> (workspace: PhotoWorkspace, warnings: [String]) {
        throw PhotoRefusal("Opening PSD files is not built yet (PS-3).")
    }
}
