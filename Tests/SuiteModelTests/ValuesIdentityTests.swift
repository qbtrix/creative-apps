// ValuesIdentityTests.swift: the ids, paths, identity rule, file key, type
// registry and error sentences every suite process shares must not drift.
import SuiteModel
import Testing

@Suite struct ValuesIdentityTests {
    @Test func bundleIDsAndPathsPerApp() {
        let expected: [SuiteApp: (String, String, String, Int)] = [
            .launcher: ("AfterGlow", "org.creativesuite.afterglow", "", 0),
            .flare: ("Flare", "org.creativesuite.flare", "Contents/Helpers/Flare.app", 1),
            .design: ("Design", "org.creativesuite.design", "Contents/Helpers/Design.app", 2),
            .photo: ("Photo", "org.creativesuite.photo", "Contents/Helpers/Photo.app", 3),
            .library: ("Library", "org.creativesuite.library", "Contents/Helpers/Library.app", 4),
            .halo: ("Halo", "org.creativesuite.halo", "Contents/Helpers/Halo.app", 5),
        ]
        for app in SuiteApp.allCases {
            let row = expected[app]
            #expect(app.displayName == row?.0)
            #expect(app.bundleID == row?.1)
            #expect(app.bundlePath == row?.2)
            #expect(app.switchDigit == row?.3)
        }
        #expect(SuiteApp.launcher.bundleID == SuiteIdentity.launcherBundleID)
        #expect(SuiteApp.apps == [.flare, .design, .photo, .library, .halo])
    }

    @Test func defaultAppPerRegistryType() {
        let registry = SuiteTypeRegistry.standard
        let expected: [(SuiteTypeID, String, SuiteApp)] = [
            (.flareAnimation, "org.creativesuite.flare.animation", .flare),
            (.designDocument, "org.creativesuite.design.document", .design),
            (.haloProject, "org.creativesuite.halo.project", .halo),
            (.photoOpenRaster, "org.creativesuite.photo.openraster", .photo),
            (.png, "public.png", .photo),
            (.jpeg, "public.jpeg", .photo),
            (.heic, "public.heic", .photo),
        ]
        #expect(registry.types.map(\.id) == expected.map(\.0))
        for (id, raw, app) in expected {
            #expect(id.rawValue == raw)
            #expect(registry.defaultApp(for: id) == app)
        }
        #expect(registry.defaultApp(for: .handOff) == nil)
        #expect(registry.type(forExtension: "JPG")?.id == .jpeg)
        #expect(registry.type(forExtension: "txt") == nil)
    }

    @Test func declaredOnlyIsTheFourExportedNonDocumentTypes() {
        let declared = SuiteTypeRegistry.declaredOnly
        #expect(declared.map(\.rawValue) == [
            "org.creativesuite.suite.handoff", "org.creativesuite.suite.asset",
            "org.creativesuite.design.layers", "org.creativesuite.flare.layers",
        ])
        let standardIDs = Set(SuiteTypeRegistry.standard.types.map(\.id))
        for id in declared { #expect(!standardIDs.contains(id)) }
    }

    @Test func fileIDIsTheStandardizedPath() {
        #expect(SuiteDocumentRef.fileID(forPath: "/a/./b/../Logo.design") == "path:/a/Logo.design")
        #expect(SuiteDocumentRef.fileID(forPath: "/a//Logo.design") == "path:/a/Logo.design")
    }

    @Test func fileKeyIsPinnedSixteenHexDigits() {
        // FNV-1a 64-bit of "path:/a/Logo.design", computed outside Swift.
        let key = SuiteDocumentRef.fileKey("path:/a/Logo.design")
        #expect(key == "a6fbe3b599b1042a")
        // The offset basis, padded to 16 digits.
        #expect(SuiteDocumentRef.fileKey("") == "cbf29ce484222325")
        let hex = Set("0123456789abcdef")
        for i in 0..<200 {
            let k = SuiteDocumentRef.fileKey("path:/tmp/Doc \(i).flare")
            #expect(k.count == 16 && k.allSatisfy { hex.contains($0) })
        }
    }

    @Test func fileKeyDiffersForTwoHundredIDs() {
        let keys = Set((0..<200).map { SuiteDocumentRef.fileKey("path:/tmp/Doc \($0).flare") })
        #expect(keys.count == 200)
    }

    @Test func everyErrorSaysItsSentence() {
        let cases: [(SuiteError, String)] = [
            (.appMissing(.flare), "Flare is missing from AfterGlow. Reinstall AfterGlow to get it back."),
            (.fileMissing(name: "Logo.design"), "Logo.design was moved or deleted."),
            (.unsupportedFile(name: "notes.txt"),
             "AfterGlow can't open \u{201C}notes.txt\u{201D}. It isn't a suite document or an image."),
            (.nothingToPaste, "Nothing to paste."),
            (.cannotPaste(app: .halo, kind: "images"), "Halo can't paste images yet."),
            (.staleRevision, "Another app changed this at the same time. Try again."),
            (.damaged("hand-off id"), "This file is damaged: hand-off id."),
            (.notAvailable("Not connected yet (home)."), "Not connected yet (home)."),
            (.cancelled, "Cancelled."),
            (.timedOut, "This took too long. Try again."),
            (.updateNotVerified, "This update couldn't be verified, so it wasn't installed."),
            (.ioFailed("disk full"), "Couldn't save: disk full."),
            (.noOtherReader(typeName: "Halo Project"), "No other app opens Halo Project files."),
            (.originalMissing(name: "IMG_0002"), "The original of IMG_0002 is missing. Locate it in Library first."),
            (.linkMissing, "Linked asset is missing; using the last copy."),
            (.updatePostponed(.design), "Update postponed: Design has unsaved changes."),
        ]
        #expect(cases.count == 16)
        for (error, sentence) in cases { #expect(error.message == sentence) }
    }

    @Test func linksAndSettingsPanesRoundTrip() {
        let link = AssetLink(assetID: "a1", kind: .vector, placedRevision: 3)
        #expect(link.kind == .vector && link.placedRevision == 3)
        #expect(AssetKind.allCases == [.color, .vector, .image, .animation])
        #expect(LinkStatus.updateAvailable(revision: 4) != .current)
        #expect(SettingsPane.app(.photo) != .general)
    }
}
