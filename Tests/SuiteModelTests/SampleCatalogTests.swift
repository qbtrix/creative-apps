// SampleCatalogTests.swift: the one sample per app the tour opens
// (onboarding OB-10's acceptance row, written first by OB-2; disabled until
// OB-10's body). A copy never overwrites; the ref names the copy.
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct SampleCatalogTests {
    let folder = "/R/Samples"

    @Test(.disabled("waits on OB-10")) func fiveSamplesOnePerAppWithTheirTypes() {
        #expect(SampleCatalog.samples.map(\.app) == SuiteApp.apps)
        #expect(SampleCatalog.samples.map(\.type) == [.flareAnimation, .designDocument, .photoOpenRaster, .png, .haloProject])
        for app in SuiteApp.apps { #expect(SampleCatalog.sample(for: app)?.app == app) }
        #expect(SampleCatalog.sample(for: .launcher) == nil)
        #expect(SampleCatalog.folder(resources: "/R") == folder)
    }

    @Test(.disabled("waits on OB-10")) func reasonOnlyWhenTheFileIsMissing() throws {
        let halo = try #require(SampleCatalog.sample(for: .halo))
        let path = folder + "/" + halo.fileName
        #expect(SampleCatalog.reason(for: halo, folder: folder, present: { $0 == path }) == nil)
        #expect(SampleCatalog.reason(for: halo, folder: folder, present: { $0 != path }) == "The Halo sample isn't in this build.")
        let photo = try #require(SampleCatalog.sample(for: .photo))
        #expect(SampleCatalog.reason(for: photo, folder: folder, present: { _ in false }) == "The Photo sample isn't in this build.")
    }

    @Test(.disabled("waits on OB-10")) func destinationNeverOverwrites() throws {
        let s = try #require(SampleCatalog.sample(for: .flare))
        var taken: Set<String> = []
        for expected in ["Bounce.flare", "Bounce 2.flare", "Bounce 3.flare"] {
            let dest = SampleCatalog.destination(for: s, documents: "/D", exists: { [taken] in taken.contains($0) })
            #expect(dest == "/D/Samples/" + expected)
            taken.insert(dest)
        }
    }

    @Test(.disabled("waits on OB-10")) func refNamesTheCopy() throws {
        let s = try #require(SampleCatalog.sample(for: .flare))
        let path = "/D/Samples/Bounce 2.flare"
        let ref = SampleCatalog.ref(for: s, path: path)
        #expect(ref.path == path && ref.app == .flare && ref.type == .flareAnimation)
        #expect(ref.displayName == "Bounce 2.flare")
        #expect(ref.fileID == SuiteDocumentRef.fileID(forPath: path))
    }
}
