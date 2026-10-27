// RawFormatTests.swift: which file names are camera RAW, and the four refusal
// sentences (shared-raw SR-3, slice SR-m, journey MJ-SR). The extensions are
// the registry's camera RAW row (`SuiteImageFormat.cameraRaw`), never a list
// of this file's. Written by SR-1/SR-2 against the stubs, turned on by SR-3.
// Mutations: SuiteImaging.RawFormat (`.anyCase`, `.cameraRawOnly`).
import SuiteImaging
import SuiteModel
import Testing

@Suite struct RawFormatTests {
    @Test(.disabled("waits on SR-3")) func everyRegistryExtensionParsesInAnyCase() throws {
        #expect(!SuiteImageFormat.cameraRaw.extensions.isEmpty)
        for ext in SuiteImageFormat.cameraRaw.extensions {
            let mixed = ext.prefix(1).uppercased() + ext.dropFirst()
            for name in ["shot.\(ext)", "SHOT.\(ext.uppercased())", "Shot.\(mixed)", "a.b.\(ext)"] {
                let format = try #require(RawFormat(fileName: name), "\(name)")
                #expect(format.fileExtension == ext.uppercased(), "\(name)")
            }
        }
    }

    @Test(.disabled("waits on SR-3")) func otherNamesAreNotRaw() {
        for name in ["DSC_0001.jpg", "a.tif", "b.png", "NEF", ".nef", "nef.", "raw", ""] {
            #expect(RawFormat(fileName: name) == nil, "\(name)")
        }
    }

    @Test(.disabled("waits on SR-3")) func refusalsAreSentences() throws {
        let nef = try #require(RawFormat(fileName: "y.NEF"))
        #expect(RawRefusal.unreadable(nef).message == "macOS can't read this raw file (NEF).")
        #expect(RawRefusal.undevelopable(camera: "Unreleased X1").message
            == "macOS can't develop raw files from Unreleased X1 yet.")
        #expect(RawRefusal.unavailable.message == "This build can't read raw files. Open it on a Mac.")
        #expect(RawRefusal.tooLarge(pixels: 300_000_000).message == "This raw file is larger than 256 megapixels.")
    }

    @Test(.disabled("waits on SR-3")) func aFormatNamesItsOwnExtension() throws {
        let dng = try #require(RawFormat(fileName: "x.dng"))
        let cr3 = try #require(RawFormat(fileName: "IMG_0001.CR3"))
        #expect(RawRefusal.unreadable(dng).message.contains("(DNG)"))
        #expect(RawRefusal.unreadable(cr3).message.contains("(CR3)"))
        #expect(dng != cr3)
    }
}
