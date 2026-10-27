// SuiteJourneyTests+Recovery.swift: SJ-AK, RJ-X44's check (adopt-kernel-autosave AK-9;
// docs/blueprints/suiteui/features/adopt-kernel-autosave.md, Journey step 6). Every editor keeps its
// recovery copies under one support root, `<support>/<App>/Recovery/`, so one `-SuiteSupportDir`
// reaches them all and no app reads (or drops) another's. Each editor first saves a document under
// its own name (`sj-flare`, `sj-design`, `sj-halo`) on a separate prep store, then reopens it on the
// one temp store, makes one edit, waits for its autosave and is killed (`terminate()`). With every
// editor down, the store holds only the apps' folders. Each then relaunches on the store with no
// document: the offer names its own document and none of the others', the other apps' copies are
// still on disk, and Restore brings the document back. Nothing is written to the real AfterGlow
// folder (its listing, `live/` aside, and each entry's modification time match before and after).
// Photo's leg skips until AK-8 moves its recovery under the root; the test runs every other leg and
// skips at the end naming the legs still waiting. Shots `<app>-suite-recovery-offer`, `-restored`.
import XCTest

final class SuiteRecoveryJourneyTests: XCTestCase {
    /// One editor: how it saves a document under `name` (prep), reopens it, and makes one edit.
    private struct Editor {
        let app: String
        /// The document's name without its extension, which the offer quotes.
        let name: String
        /// The recovery copy's extension, as `<support>/<App>/Recovery/<window>.<ext>`.
        let ext: String
        /// Launches on a fixture and saves it as `name` in `folder`; returns the saved file.
        let save: @MainActor (SuiteRecoveryJourneyTests, URL, [String]) throws -> URL
        /// The launch arguments that open `file`.
        let open: (URL) -> [String]
        let edit: @MainActor (Journey) -> Void
    }

    /// The editors whose leg runs; AK-8 adds Photo.
    private static let live: Set<String> = ["Flare", "Design", "Halo"]
    private static let apps = ["Photo", "Flare", "Design", "Halo"]
    private static let offerPrefix = "Restore the autosaved changes to "

    /// SJ-AK: four editors killed mid-edit under one `-SuiteSupportDir` each offer their own edit back.
    @MainActor func testFourEditorsRecoverFromOneRoot() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "suite-recovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let support = folder.appending(path: "support"), prep = ["-SuiteSupportDir", folder.appending(path: "prep").path]
        let store = ["-SuiteSupportDir", support.path]
        let real = Self.realListing()

        var waiting: [String] = [], editors: [Editor] = []
        for app in Self.apps {
            do {
                editors.append(try Self.editor(app))
            } catch let skip as XCTSkip {
                waiting.append("\(app): \(skip.message ?? "skipped")")
            }
        }
        XCTAssertFalse(editors.isEmpty, "no editor's leg runs")

        // 1. Each editor: its own document reopened on the store, one edit, the autosave, then killed.
        for editor in editors {
            let file = try editor.save(self, folder, prep)
            let journey = launch(editor.app, store + editor.open(file))
            editor.edit(journey)
            XCTAssert(waitFor(seconds: 60) { !self.copies(editor, support).isEmpty },
                      "\(editor.app): no copy autosaved under \(support.path)/\(editor.app)/Recovery")
            journey.app.terminate()
        }

        // 2. The store holds only the apps' folders, nothing at its top level.
        let top = (try? FileManager.default.contentsOfDirectory(atPath: support.path)) ?? []
        let stray = top.filter { !Self.apps.contains($0) }
        XCTAssert(stray.isEmpty, "the support root holds \(stray) beside the apps' folders")
        for editor in editors { XCTAssert(top.contains(editor.app), "the support root has no \(editor.app)/") }

        // 3. Each relaunch on the store offers only its own document; the others' copies survive; Restore.
        let saved = Dictionary(uniqueKeysWithValues: editors.map { ($0.app, copies($0, support)) })
        for editor in editors {
            let journey = launch(editor.app, store)
            let offer = journey.app.staticTexts.matching(NSPredicate(
                format: "label BEGINSWITH %@ OR value BEGINSWITH %@", Self.offerPrefix, Self.offerPrefix)).firstMatch
            XCTAssert(offer.waitForExistence(timeout: 30), "\(editor.app): the relaunch offered no restore")
            let text = [offer.label, offer.value as? String ?? ""].first { $0.hasPrefix(Self.offerPrefix) } ?? offer.label
            XCTAssert(text.contains("\u{201C}\(editor.name)"), "\(editor.app): the offer reads \(text), not its own \(editor.name)")
            for other in editors where other.app != editor.app {
                XCTAssertFalse(text.contains(other.name), "\(editor.app): the offer names \(other.app)'s \(other.name)")
                let left = Set(copies(other, support))
                XCTAssert(left.isSuperset(of: saved[other.app] ?? []), "\(editor.app)'s launch removed \(other.app)'s copy")
            }
            journey.shot("suite-recovery-offer")
            let restore = journey.app.buttons["suite.recovery.restore"].firstMatch
            XCTAssert(restore.waitForExistence(timeout: 5), "\(editor.app): the offer has no Restore (suite.recovery.restore)")
            restore.click()
            XCTAssert(offer.waitForNonExistence(timeout: 10), "\(editor.app): the offer stayed up after Restore")
            XCTAssert(journey.element("suite.canvas").waitForExistence(timeout: 15), "\(editor.app): Restore showed no canvas")
            journey.shot("suite-recovery-restored")
            journey.app.terminate()
        }

        // 4. Nothing was written to the real AfterGlow folder.
        XCTAssertEqual(Self.realListing(), real, "the journey wrote to the real AfterGlow folder")
        if !waiting.isEmpty { throw XCTSkip(waiting.joined(separator: "; ")) }
    }

    // MARK: - Editors

    /// The editor's leg; a leg that can't run yet throws its XCTSkip, and the others still run.
    @MainActor private static func editor(_ app: String) throws -> Editor {
        guard live.contains(app) else { throw XCTSkip("waits on AK-8") }
        switch app {
        case "Flare":
            return Editor(
                app: "Flare", name: "sj-flare", ext: "flare",
                save: { test, folder, prep in
                    let flare = test.launch("Flare", prep + ["-FlareFixture", "bounce", "-FlareSaveTo", folder.path])
                    let save = flare.app.toolbars.firstMatch.buttons["flare.file.save"]
                    XCTAssert(save.waitForExistence(timeout: 10), "Flare: no Save (flare.file.save)")
                    save.click()
                    let untitled = folder.appending(path: "Untitled.flare"), file = folder.appending(path: "sj-flare.flare")
                    XCTAssert(test.waitFor { FileManager.default.fileExists(atPath: untitled.path) }, "Flare: Save wrote no Untitled.flare")
                    flare.app.terminate()
                    try FileManager.default.moveItem(at: untitled, to: file)
                    return file
                },
                open: { ["-FlareOpenFile", $0.path] },
                edit: { flare in
                    let newLayer = flare.element("suite.sidebar").buttons["New Layer"]
                    XCTAssert(newLayer.waitForExistence(timeout: 15), "Flare: the sidebar has no New Layer")
                    newLayer.click()
                })
        case "Design":
            return Editor(
                app: "Design", name: "sj-design", ext: "design",
                save: { test, folder, prep in
                    let file = folder.appending(path: "sj-design.design")
                    let design = test.launch("Design", prep + ["-DesignServices", "live", "-SuiteWindowSize", "1024x768",
                                                              "-DesignFixture", "cards", "-DesignSaveTo", file.path])
                    design.press(character: "s", .command)
                    XCTAssert(test.waitFor { FileManager.default.fileExists(atPath: file.path) }, "Design: ⌘S wrote no sj-design.design")
                    design.app.terminate()
                    return file
                },
                open: { ["-DesignServices", "live", "-SuiteWindowSize", "1024x768", "-DesignOpenFile", $0.path] },
                edit: { design in
                    design.element("suite.tools").buttons["Rectangle"].click()
                    design.drag(on: "suite.canvas", from: CGVector(dx: 0.56, dy: 0.61), to: CGVector(dx: 0.70, dy: 0.75))
                })
        case "Halo":
            return Editor(
                app: "Halo", name: "sj-halo", ext: "halo",
                save: { test, folder, prep in
                    let file = folder.appending(path: "sj-halo.halo")
                    let halo = test.launch("Halo", prep + ["-HaloWindowSize", "1000x640", "-HaloSample", "keyed",
                                                          "-HaloSaveTo", file.path])
                    halo.press(character: "s", .command)
                    XCTAssert(test.waitFor { FileManager.default.fileExists(atPath: file.path) }, "Halo: ⌘S wrote no sj-halo.halo")
                    halo.app.terminate()
                    return file
                },
                open: { ["-HaloWindowSize", "1000x640", "-HaloOpenFile", $0.path] },
                edit: { halo in
                    halo.element("halo.composition.new").click()
                    halo.click("Create", in: .sheet)
                })
        default:
            throw XCTSkip("waits on AK-8")
        }
    }

    // MARK: - Steps

    /// Launches `app` with `arguments` and waits for its window.
    @MainActor fileprivate func launch(_ app: String, _ arguments: [String]) -> Journey {
        let journey = Journey(app, self, arguments: arguments)
        XCTAssert(journey.app.windows.firstMatch.waitForExistence(timeout: 30), "\(app): no window opened")
        return journey
    }

    /// The editor's recovery copies under `support`.
    private func copies(_ editor: Editor, _ support: URL) -> [String] {
        let folder = support.appending(path: "\(editor.app)/Recovery").path
        return ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []).filter { $0.hasSuffix(".\(editor.ext)") }
    }

    /// Every path under the real `~/Library/Application Support/AfterGlow` but `live/` (the live
    /// command channel's sockets), with its modification time. The home comes from the user record,
    /// since a sandboxed runner's NSHomeDirectory() is its container.
    private static func realListing() -> [String: Date] {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        let root = URL(fileURLWithPath: home).appending(path: "Library/Application Support/AfterGlow")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else { return [:] }
        var listing: [String: Date] = [:]
        while let path = walker.nextObject() as? String {
            if path == "live" { walker.skipDescendants(); continue }
            let date = (try? FileManager.default.attributesOfItem(atPath: root.appending(path: path).path))?[.modificationDate]
            listing[path] = date as? Date ?? .distantPast
        }
        return listing
    }

    /// Whether `condition` holds within `seconds`.
    fileprivate func waitFor(seconds: Int = 10, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 5) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
