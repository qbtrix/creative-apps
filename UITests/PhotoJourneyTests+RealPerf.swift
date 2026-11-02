// PhotoJourneyTests+RealPerf.swift: Photo's real-app perf journeys. Each test
// opens the 8K test photo `scripts/ui-test perf` writes (7680 x 4320,
// .build/realperf/eight-k.png; the sandboxed runner can only write inside its
// container, and to Photo a file there is another app's data) in the
// real-perf copy of Photo through -PhotoOpenFile (the .live path a person's
// file takes), autosaving into .build/realperf/recovery-<backend>, in a
// 1700 x 1000 window. View > Rendering is forced by the launch argument
// `-suite.rendering gpu|cpu` (the argument domain overrides the shared
// default without writing it; it goes before the bare -SuitePerfProbe flag,
// which AppKit would otherwise read as its key with the next word left over
// as a file to open, and Photo then opens no window), and the status line
// must name that backend when XCUITest can read it.
// When the photo doesn't open, the failure says why: the app's state and
// windows, its status message, and the frames of a Photo crash report
// written meanwhile. Then it drives, about 3 s each: the Levels Black slider,
// the Hue slider, the Move tool across the canvas, a scroll-wheel pan at
// 300%, and ⌘= / ⌘− zoom steps. Pinch isn't driven: XCUITest on macOS can't
// make a magnify gesture, so the zoom keys stand in. Every gesture goes
// through Journey.health (Journey+Health.swift). Only `scripts/ui-test perf`
// runs these (nightly, from perf-nightly.sh); Tests/render-budgets.md records
// what they measured.
import AppKit
import XCTest

final class PhotoRealPerfJourneyTests: XCTestCase {
    @MainActor func testEightKGPU() throws { try run(backend: "gpu", status: "GPU (Metal)") }
    @MainActor func testEightKCPU() throws { try run(backend: "cpu", status: "CPU") }

    @MainActor private func run(backend: String, status: String) throws {
        let file = Health.out.appending(path: "eight-k.png")
        guard FileManager.default.fileExists(atPath: file.path) else {
            return XCTFail("no \(file.path): run these through scripts/ui-test perf")
        }
        let arguments = photoArguments(open: file, recoveryDir: Health.out.appending(path: "recovery-\(backend)"), windowSize: "1700x1000") + ["-suite.rendering", backend, "-SuitePerfProbe"]
        let photo = Journey.realPerf("Photo", self, arguments: arguments)
        let header = photo.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "7680 × 4320 px")).firstMatch
        let launched = Date()
        guard header.waitForExistence(timeout: 120) else {
            return XCTFail("the 8K photo didn't open on \(backend) (no 7680 × 4320 px): \(Self.why(photo, since: launched))")
        }
        // XCUITest often reads a SwiftUI Text's label as empty (#262): only a backend it can read is checked.
        let render = photo.element("photo.status.render")
        XCTAssert(render.waitForExistence(timeout: 30), "the status line shows no render time (photo.status.render)")
        let drew = [render.label, render.value as? String ?? ""].first { !$0.isEmpty } ?? ""
        print("realperf photo \(backend): status line reads \(drew.isEmpty ? "(unreadable)" : drew)")
        XCTAssert(drew.isEmpty || drew.hasPrefix(status), "-suite.rendering \(backend) drew on \(drew), not \(status)")
        guard let pid = photo.pid(of: "Photo") else { return XCTFail("no running Photo from .build/realperf (scripts/ui-test perf makes it)") }

        for (label, title) in [("levels", "Black"), ("hue-sat", "Hue")] {
            let slider = photo.app.sliders[title]
            guard slider.waitForExistence(timeout: 10) else { XCTFail("no \(title) slider"); continue }
            photo.reveal(slider)
            photo.health("\(backend) \(label)", pid: pid, series: "bar-slider") { photo.scrub(slider); return [] }
            photo.press(character: "z", .command)
        }

        let viewport = photo.element("suite.viewport")
        photo.element("suite.tools").buttons["Select"].click()
        photo.health("\(backend) move", pid: pid, series: "canvas-drag") {
            let span = viewport.frame.width * 0.4, scale = NSScreen.main?.backingScaleFactor ?? 1
            viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click(
                forDuration: 0.05, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)),
                withVelocity: XCUIGestureVelocity(span * scale / 3), thenHoldForDuration: 0.05)
            return []
        }
        photo.press(character: "z", .command)

        for _ in 0..<3 { photo.press(character: "=", .command) }
        photo.health("\(backend) pan", pid: pid, series: nil) {
            Journey.repeatFor(seconds: 3) { step in
                viewport.scroll(byDeltaX: step.isMultiple(of: 2) ? 80 : -80, deltaY: step.isMultiple(of: 4) ? 60 : -60)
            }
        }
        photo.health("\(backend) zoom", pid: pid, series: nil) {
            Journey.repeatFor(seconds: 3) { step in photo.press(character: step.isMultiple(of: 2) ? "-" : "=", .command) }
        }
    }

    /// Why the photo didn't open: the app's state and windows, its status message, and the
    /// telling frames of a Photo crash report written since `since`, if one was.
    @MainActor static func why(_ photo: Journey, since: Date) -> String {
        var parts = ["app state \(photo.app.state.rawValue) (1 not running, 4 foreground)"]
        if photo.app.state != .notRunning {
            parts.append("\(photo.app.windows.count) window(s)")
            let message = photo.element("photo.status.message")
            if message.exists { parts.append("status: \(message.label)") }
        }
        // The runner's own home is its sandbox container; the reports are under the user's.
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        let reports = URL(fileURLWithPath: home).appending(path: "Library/Logs/DiagnosticReports")
        let crash = (try? FileManager.default.contentsOfDirectory(
            at: reports, includingPropertiesForKeys: [.contentModificationDateKey]))?
            .filter { $0.lastPathComponent.hasPrefix("Photo") && $0.pathExtension == "ips" }
            .filter { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) > since }
            .first
        if let crash, let text = try? String(contentsOf: crash, encoding: .utf8) {
            // The report keeps symbols, not Metal's assertion text; name the frames that matter.
            let frames = ["SIGABRT", "MTLTextureDescriptorInternal validateWithDevice", "MPSAutoCache::GetTempTexture",
                          "CanvasTilePresenter.present"].filter { text.contains($0) }
            parts.append("crashed: \(crash.lastPathComponent) (\(frames.joined(separator: ", ")))")
        }
        return parts.joined(separator: "; ")
    }
}
