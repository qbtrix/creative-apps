// AllAppsCatalogTests.swift (adopt-command-catalog AC-z1): one walk over every app the CLI knows. `list-apps` and each
// app's `list-commands` match their goldens in Golden/apps/, every catalog keeps the kernel's laws on a real job's
// input, and every real job under Tests/RealJobs/<app>/ passes or is skipped for a reason that names its gap.
import AfterGlowCLICore
import DesignModel
import FlareModel
import Foundation
import HaloModel
import LibraryModel
import PhotoModel
import Testing

struct AllAppsCatalogTests {
    /// The five apps in `Apps.all` order.
    static let names = ["photo", "design", "flare", "halo", "library"]

    /// Runs `afterglow <arguments>` over the registry the shipped binary uses, and reads back its one stdout line.
    static func printed(_ arguments: [String]) throws -> JSONValue {
        let io = FakeIO()
        let code = CLI.run(arguments, io: io)
        #expect(code == 0, "\(arguments) exited \(code): \(io.stderr)")
        #expect(io.stdout.count == 1, "\(arguments) printed \(io.stdout)")
        return try JSONValue(json: Data((io.stdout.first ?? "").utf8))
    }

    /// The golden `Golden/apps/<name>.json`.
    static func golden(_ name: String) throws -> JSONValue {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Golden/apps").appendingPathComponent("\(name).json")
        return try JSONValue(json: try Data(contentsOf: file))
    }

    @Test func listAppsMatchesItsGolden() throws {
        let apps = try Self.printed(["list-apps"])
        #expect(apps == (try Self.golden("list-apps")), "list-apps differs")
        guard case .object(let fields) = apps, case .array(let listed)? = fields["apps"] else { Issue.record("no apps"); return }
        let named = listed.compactMap { app -> String? in
            if case .object(let f) = app, case .string(let name)? = f["name"] { name } else { nil }
        }
        #expect(named == Self.names + ["suite", "fake", "fake-tone"], "list-apps lists the five in registry order, the suite, then the fakes")
    }

    @Test(arguments: names)
    func listCommandsMatchesItsGolden(app: String) throws {
        let commands = try Self.printed([app, "list-commands"])
        #expect(commands == (try Self.golden("\(app).list-commands")), "\(app) list-commands differs")
        guard case .object(let fields) = commands, case .array(let listed)? = fields["commands"] else { Issue.record("no commands"); return }
        #expect(fields["app"] == .string(app))
        #expect(!listed.isEmpty, "\(app) lists no commands")
    }

    // MARK: Laws on each app's real-job input

    /// The law problems each app has today on its fixture, as "<id>: <law>", by reason. Each is a gap for a later slice.
    static let tolerated: [String: [String]] = [
        "Design's select example names node-1, which a real file need not hold": ["edit.select: exampleRuns"],
        "Halo saves the playhead and the selection in the file": [
            "animation.go-to-end: queryOrViewChangesNoBytes", "animation.next-frame: queryOrViewChangesNoBytes",
            "easing.select-lane-keys: queryOrViewChangesNoBytes", "timeline.pick-keys: queryOrViewChangesNoBytes",
            "layer.select: queryOrViewChangesNoBytes",
            "timeline.scrub: queryOrViewChangesNoBytes", "viewer.drag-begin: queryOrViewChangesNoBytes"],
        "The kernel's place.image example is an SVG, which Photo doesn't place": ["place.image: exampleRuns"],
        "The kernel's shape.draw names its step for the kind drawn (\"Draw Star\")": ["shape.draw: stepNamedTitle"],
        "Halo's drag end with no drag is a no-op edit that stays enabled": [
            "viewer.drag-end: stepNamedTitle", "viewer.drag-end: editRecordsOneStep", "viewer.drag-end: undoRestoresBytes"],
        "The kernel's transform.flip and image.flip are titled Flip while their steps name the axis": [
            "transform.flip: stepNamedTitle", "image.flip: stepNamedTitle"],
        "The kernel's tone.set is titled Tone while its step names the slider": ["tone.set: stepNamedTitle"],
        // PY-5 (layer-styles) fills Photo's style adapter and drops this entry.
        "Photo's style.* runs throw notBuilt until layer-styles PY-5": [
            "style.add: exampleRuns", "style.enable: exampleRuns", "style.fill-opacity: exampleRuns", "style.panel: exampleRuns",
            "style.paste: exampleRuns", "style.preset: exampleRuns", "style.read: exampleRuns", "style.remove: exampleRuns",
            "style.set: exampleRuns"],
        "Photo's square.png is flat where the heal examples act, so they change no pixel and record no step": [
            "retouch.spot-heal: stepNamedTitle", "retouch.spot-heal: editRecordsOneStep", "retouch.spot-heal: undoRestoresBytes",
            "retouch.remove: stepNamedTitle", "retouch.remove: editRecordsOneStep", "retouch.remove: undoRestoresBytes"],
    ]

    /// `D`'s law problems on the real job input `path`, as "<id>: <law>", less an example that can't run because its
    /// command says why it is unavailable on this file; and how many of its commands are available there.
    static func laws<D: HeadlessDocument>(_ type: D.Type, _ path: String) throws -> (problems: [String], available: Int) {
        let url = RealJobsHarness.root.appendingPathComponent(RealJobsHarness.jobsTree).appendingPathComponent(path)
        let doc = try D.open(try Data(contentsOf: url), name: url.lastPathComponent)
        let problems = CatalogConformance.check(D.self, fixture: doc).compactMap { problem -> String? in
            let parts = problem.split(separator: ":", maxSplits: 2).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { return problem }
            let unavailable = D.catalog.availability(parts[0], on: doc).why != nil
            return parts[1] == "exampleRuns" && unavailable ? nil : "\(parts[0]): \(parts[1])"
        }
        return (problems, D.catalog.ids.filter { D.catalog.availability($0, on: doc).why == nil }.count)
    }

    /// Each app's catalog and the real job input it is checked on.
    static let fixtures: [(String, @Sendable () throws -> (problems: [String], available: Int))] = [
        ("photo", { try laws(PhotoHeadless.self, "photo/batch-resize/input/square.png") }),
        ("design", { try laws(DesignHeadless.self, "design/align-and-save/input/three-cards.design") }),
        ("flare", { try laws(FlareHeadless.self, "flare/export-svg-frames/input/ball.flare") }),
        ("halo", { try laws(HaloHeadless.self, "halo/retitle-and-save/input/card.halo") }),
        ("library", { try laws(LibraryHeadless.self, "library/cull-and-save/input/shoot.library") }),
    ]

    @Test func everyCatalogKeepsTheLawsOnARealFile() throws {
        #expect(Self.fixtures.map(\.0) == Self.names)
        let known = Set(Self.tolerated.values.joined())
        var seen = Set<String>()
        for (app, check) in Self.fixtures {
            let (problems, available) = try check()
            #expect(available > 0, "\(app): no command is available on its fixture")
            #expect(problems.filter { !known.contains($0) } == [], "\(app) breaks a law")
            seen.formUnion(problems)
        }
        #expect(known.subtracting(seen).sorted() == [], "a tolerated problem is fixed: drop it from the table")
    }

    // MARK: Real jobs

    /// The `pending` issue a job's script names ("#3273"), nil when it has none.
    static func pending(_ job: String) throws -> String? {
        guard let script = RealJobsHarness.scripts(in: job).first else { return nil }
        let data = try Data(contentsOf: RealJobsHarness.root.appendingPathComponent(job).appendingPathComponent(script))
        guard case .object(let fields) = try JSONValue(json: data), case .string(let issue)? = fields["pending"] else { return nil }
        return issue
    }

    @Test func everyAppsRealJobIsGreenOrPendingWithAGap() throws {
        let jobs = RealJobsHarness.jobs(in: RealJobsHarness.jobsTree)
        for app in Self.names {
            #expect(jobs.contains { $0.hasPrefix("\(RealJobsHarness.jobsTree)/\(app)/") }, "\(app) has no real job")
        }
        for job in jobs where !job.hasPrefix("\(RealJobsHarness.jobsTree)/fake/") {
            let io = RealJobsHarness.mount(job)
            let code = RealJobs.check(job, apps: RealJobsHarness.apps, io: io)
            let report = try #require(RealJobsHarness.report(io), "\(job) printed \(io.stdout)")
            #expect(code == 0, "\(job) exited \(code): \(RealJobsHarness.printed(io))")
            let issue = try Self.pending(job)
            guard case .string(let why)? = report["skipped"] else {
                #expect(report["ok"] == .bool(true), "\(job): \(RealJobsHarness.printed(io))")
                #expect(issue == nil, "\(job) passes: drop its pending \(issue ?? "")")
                continue
            }
            let gap = issue.map { why.contains($0) } ?? why.contains("waits on image-codecs (qbtrix/creative-core#562)")
            #expect(gap, "\(job) skipped without naming its gap: \(why)")
        }
    }
}
