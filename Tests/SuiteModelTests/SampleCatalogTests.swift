// SampleCatalogTests.swift: the one sample per app the tour opens
// (onboarding OB-10's acceptance row, written first by OB-2, turned on by
// OB-10). A copy never overwrites; the ref names the copy.
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct SampleCatalogTests {
    let folder = "/R/Samples"

    @Test func fiveSamplesOnePerAppWithTheirTypes() {
        #expect(SampleCatalog.samples.count == 5)
        #expect(SampleCatalog.samples.map(\.app) == SuiteApp.apps)
        #expect(SampleCatalog.samples.map(\.type) == [.flareAnimation, .designDocument, .photoOpenRaster, .png, .haloProject])
        for app in SuiteApp.apps { #expect(SampleCatalog.sample(for: app)?.app == app) }
        #expect(SampleCatalog.sample(for: .launcher) == nil)
        #expect(SampleCatalog.folder(resources: "/R") == folder)
        #expect(SampleCatalog.folder(resources: "/Applications/AfterGlow.app/Contents/Resources")
            == "/Applications/AfterGlow.app/Contents/Resources/Samples")
    }

    @Test func sampleTitlesAreCapitalisedDisplayNames() {
        // The start page's help reads "Open <title> in <App>.", so each title is a capitalised name (#2851).
        #expect(SampleCatalog.samples.map(\.title) == ["Bounce", "Cards", "Beach", "Sunset", "Intro"])
        for s in SampleCatalog.samples { #expect(s.title.first?.isUppercase == true) }
    }

    @Test func reasonOnlyWhenTheFileIsMissing() throws {
        let halo = try #require(SampleCatalog.sample(for: .halo))
        let path = folder + "/" + halo.fileName
        #expect(SampleCatalog.reason(for: halo, folder: folder, present: { $0 == path }) == nil)
        #expect(SampleCatalog.reason(for: halo, folder: folder, present: { $0 != path }) == "The Halo sample isn't in this build.")
        let photo = try #require(SampleCatalog.sample(for: .photo))
        #expect(SampleCatalog.reason(for: photo, folder: folder, present: { _ in false }) == "The Photo sample isn't in this build.")
    }

    @Test func destinationNeverOverwrites() throws {
        let s = try #require(SampleCatalog.sample(for: .flare))
        var taken: Set<String> = []
        for expected in ["Bounce.flare", "Bounce 2.flare", "Bounce 3.flare"] {
            let found = SampleCatalog.destination(for: s, documents: "/D", exists: { [taken] in taken.contains($0) })
            let dest = try #require(found)
            #expect(dest == "/D/Samples/" + expected)
            taken.insert(dest)
        }
    }

    @Test func destinationSkipsEveryTakenNameInARow() throws {
        let s = try #require(SampleCatalog.sample(for: .flare))
        let taken: Set<String> = ["/D/Samples/Bounce.flare", "/D/Samples/Bounce 2.flare", "/D/Samples/Bounce 3.flare"]
        let found = SampleCatalog.destination(for: s, documents: "/D", exists: { taken.contains($0) })
        let dest = try #require(found)
        #expect(dest == "/D/Samples/Bounce 4.flare")
        #expect(!taken.contains(dest))
    }

    @Test func refNamesTheCopy() throws {
        let s = try #require(SampleCatalog.sample(for: .flare))
        let path = "/D/Samples/Bounce 2.flare"
        let ref = SampleCatalog.ref(for: s, path: path)
        #expect(ref.path == path && ref.app == .flare && ref.type == .flareAnimation)
        #expect(ref.displayName == "Bounce 2.flare")
        #expect(ref.fileID == SuiteDocumentRef.fileID(forPath: path))
    }

    @Test func eachSamplesRefDiffers() {
        let refs = SampleCatalog.samples.map { s in
            SampleCatalog.ref(for: s, path: SampleCatalog.destination(for: s, documents: "/D", exists: { _ in false }) ?? "")
        }
        #expect(Set(refs.map(\.path)).count == SampleCatalog.samples.count)
        #expect(Set(refs.map(\.fileID)).count == SampleCatalog.samples.count)
        #expect(Set(refs.map(\.displayName)) == Set(SampleCatalog.samples.map(\.fileName)))
        #expect(refs.map(\.app) == SuiteApp.apps)
    }

    @Test func destinationIsTheFirstFreeNameAndKeepsADotlessName() throws {
        let s = try #require(SampleCatalog.sample(for: .halo))
        let gap: Set<String> = ["/D/Samples/Intro.halo", "/D/Samples/Intro 3.halo"]
        #expect(SampleCatalog.destination(for: s, documents: "/D", exists: { gap.contains($0) }) == "/D/Samples/Intro 2.halo")
        #expect(SampleCatalog.destination(for: s, documents: "/D", exists: { _ in false }) == "/D/Samples/Intro.halo")
        let bare = SampleFile(app: .photo, fileName: "README", type: .png, title: "README")
        #expect(SampleCatalog.destination(for: bare, documents: "/D", exists: { $0 == "/D/Samples/README" }) == "/D/Samples/README 2")
    }

    @Test func destinationSkipsATakenNameInAnotherCaseAsUniqueFileNamesDoes() throws {
        // `exists` answers as the file system does: on APFS (case-insensitive) "bounce.flare" takes "Bounce.flare".
        let s = try #require(SampleCatalog.sample(for: .flare))
        let onDisk = ["bounce.flare", "BOUNCE 2.flare", "Bounce 4.flare"]
        let folded = Set(onDisk.map { ("/D/Samples/" + $0).lowercased() })
        let dest = SampleCatalog.destination(for: s, documents: "/D", exists: { folded.contains($0.lowercased()) })
        #expect(dest == "/D/Samples/Bounce 3.flare")
        #expect(dest == "/D/Samples/" + UniqueFileNames.name("Bounce", extension: "flare", among: Set(onDisk)))
    }

    @Test func destinationKeepsTheSampleNameAsIs() {
        let dotted = SampleFile(app: .photo, fileName: "my.beach.ora", type: .photoOpenRaster, title: "Beach")
        #expect(SampleCatalog.destination(for: dotted, documents: "/D", exists: { $0 == "/D/Samples/my.beach.ora" })
            == "/D/Samples/my.beach 2.ora")
        let hidden = SampleFile(app: .photo, fileName: ".ora", type: .photoOpenRaster, title: "Beach")
        #expect(SampleCatalog.destination(for: hidden, documents: "/D", exists: { $0 == "/D/Samples/.ora" }) == "/D/Samples/.ora 2")
    }

    @Test func destinationGivesUpWhenEveryNameIsTaken() throws {
        let s = try #require(SampleCatalog.sample(for: .flare))
        let asked = SampleCopyLog()
        #expect(SampleCatalog.destination(for: s, documents: "/D", exists: { asked.record($0, ""); return true }) == nil)
        #expect(asked.all.count == SampleCatalog.maxTries)
        #expect(SampleCatalog.maxTries == 1000)
        let last = "/D/Samples/Bounce \(SampleCatalog.maxTries).flare"
        #expect(SampleCatalog.destination(for: s, documents: "/D", exists: { $0 != last }) == last)
    }
}
