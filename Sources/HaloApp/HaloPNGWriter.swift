// HaloPNGWriter.swift: the PNG sequence sink (render-out RO-6, #429). Render…
// hands it a folder URL; `begin` makes that folder (and any missing parents)
// and refuses a path that is already a file, so no frame lands over it.
// `write` turns each frame into an sRGB, straight-alpha image through
// HaloFrameImage, the same image the viewer shows (RO-5), and writes it as
// one PNG named by the plan through CGImageDestination. `finish` keeps every
// frame written so far, cancelled or not: a cancelled sequence leaves its
// first frames on disk. Errors say what went wrong in words the render
// sheet shows. macOS only.
import CoreGraphics
import Foundation
import HaloModel
import ImageIO
import UniformTypeIdentifiers

struct HaloPNGWriter: RenderSink, Sendable {
    enum Failure: Error, CustomStringConvertible, Equatable {
        /// The folder's name: a file is already at the folder's path.
        case fileInTheWay(String)
        /// The folder's name: it couldn't be made.
        case noFolder(String)
        /// The frame's file name: it couldn't be written.
        case unwritable(String)

        var description: String {
            switch self {
            case .fileInTheWay(let name): "A file named “\(name)” is already there."
            case .noFolder(let name): "The folder “\(name)” couldn't be made."
            case .unwritable(let name): "\(name) couldn't be written."
            }
        }
    }

    /// Where the frames go.
    let folder: URL
    /// The file names written so far, in order.
    private(set) var written: [String] = []

    init(folder: URL) { self.folder = folder }

    mutating func begin(_ plan: HaloRenderPlan) throws {
        let isFolder = (try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
        if isFolder == false { throw Failure.fileInTheWay(folder.lastPathComponent) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw Failure.noFolder(folder.lastPathComponent)
        }
        written = []
    }

    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        let url = folder.appending(path: fileName)
        guard let image = HaloFrameImage.cgImage(frame),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw Failure.unwritable(fileName) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.unwritable(fileName) }
        written.append(fileName)
    }

    /// Keeps the written frames either way; there is nothing to close.
    mutating func finish(cancelled: Bool) throws {}
}
