// PhotoDropCLITests.swift (file-flow RJ-P42, #3741): `afterglow photo file.drop` places a dropped image into the
// open image as a layer, fitted inside the canvas, reading the dropped file through the CLI's file system only; a
// dropped file that isn't there is refused and nothing is written. In process, on a FakeIO; runs on Linux and macOS.
import AfterGlowCLICore
import CoreRaster
import Foundation
import PhotoModel
import Testing

@Suite struct PhotoDropCLITests {
    /// A `width` x `height` opaque red PNG.
    static func png(_ width: Int, _ height: Int) throws -> Data {
        let red = DecodedImage(rgba8: Array([[UInt8]](repeating: [255, 0, 0, 255], count: width * height).joined()),
                               width: width, height: height)
        return try CoreRasterImageCodec().encode(red, as: .png, quality: 1)
    }

    @Test func aDroppedPhotoIsPlacedFittedAndSaved() throws {
        let io = FakeIO(files: ["base.png": try Self.png(4, 3), "drops/Big.png": try Self.png(40, 20)])
        let code = CLI.run(["photo", "file.drop", "--in", "base.png", "--out", "out.ora",
                            "--json", #"{"paths":["drops/Big.png"]}"#], io: io)
        #expect(code == 0, "file.drop exited \(code): \(io.stderr)")
        let saved = try #require(io.files["out.ora"], "nothing saved")
        let doc = try PhotoHeadless.open(saved, name: "out.ora")
        let layer = try #require(doc.workspace.layers.first { $0.name == "Big" }, "no Big layer")
        #expect(doc.workspace.pixels[layer.id]?.width == 4 && doc.workspace.pixels[layer.id]?.height == 2,
                "not fitted inside 4 x 3")
    }

    @Test func aMissingDroppedFileIsRefused() throws {
        let io = FakeIO(files: ["base.png": try Self.png(4, 3)])
        let code = CLI.run(["photo", "file.drop", "--in", "base.png", "--out", "out.ora",
                            "--json", #"{"paths":["drops/Gone.png"]}"#], io: io)
        #expect(code != 0)
        #expect(io.files["out.ora"] == nil, "a refused drop wrote a file")
    }
}
