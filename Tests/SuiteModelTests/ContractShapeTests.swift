// ContractShapeTests.swift: the nine tier-1 contracts keep blueprint 5.2's
// signatures. One minimal conformer per protocol (Shape*, so they never
// collide with the Fake* types) calls every requirement once inside
// `do throws(SuiteError)`; a drifted signature stops this file compiling.
// The `changes()` streams of RecentWork and AppSwitching must yield.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

private let shapeNow = Date(timeIntervalSince1970: 1_800_000_000)

private func shapeRef(_ name: String = "Logo.design") -> SuiteDocumentRef {
    let path = "/tmp/Documents/" + name
    return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                            type: .designDocument, displayName: name)
}

private func shapeHandOff(verb: HandOffVerb = .open) -> HandOff {
    HandOff(id: HandOff.newID(), from: .launcher, to: .design, verb: verb, documents: [shapeRef()], createdAt: shapeNow)
}

/// A stream that yields each value once, then finishes.
private func shapeStream(_ values: [Int]) -> AsyncStream<Int> {
    AsyncStream { c in
        for v in values { c.yield(v) }
        c.finish()
    }
}

private actor ShapeSwitching: AppSwitching {
    var running: Set<SuiteApp> = []
    var revision = 0
    func runState(of app: SuiteApp) async -> AppRunState { running.contains(app) ? .running(windows: 1) : .notRunning }
    func changes() async -> AsyncStream<Int> { shapeStream([revision]) }
    func switchTo(_ app: SuiteApp, reason: SwitchReason) async throws(SuiteError) -> SwitchReceipt {
        if app == .launcher, reason == .handOff { throw .cancelled }
        let was = running.contains(app)
        running.insert(app); revision += 1
        return SwitchReceipt(app: app, wasRunning: was, requestedAt: 1)
    }
}

private actor ShapeRecents: RecentWork {
    var recents = RecentsList()
    func list() async throws(SuiteError) -> RecentsList { recents }
    func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) async throws(SuiteError) {
        recents.note(RecentItem(ref: ref, lastUsed: date, thumbnail: thumbnail)); recents.revision += 1
    }
    func remove(fileID: String) async throws(SuiteError) { recents.remove(fileID: fileID); recents.revision += 1 }
    func clear(app: SuiteApp) async throws(SuiteError) { recents.clear(app: app); recents.revision += 1 }
    func changes() async -> AsyncStream<Int> { shapeStream([recents.revision]) }
}

private struct ShapeCreating: DocumentCreating {
    let preset = NewDocumentPreset(id: "design.square", app: .design, title: "Square", detail: "1080 × 1080")
    func tiles(missing: Set<SuiteApp>) -> [NewTile] {
        [NewTile(app: .design, title: "New Design", presets: [preset],
                 disabledReason: missing.contains(.design) ? SuiteError.appMissing(.design).message : nil)]
    }
    func handOff(for preset: NewDocumentPreset, id: String, at date: Date) -> HandOff {
        HandOff(id: id, from: .launcher, to: preset.app, verb: .new, preset: preset, createdAt: date)
    }
}

private struct ShapeRouting: DocumentRouting {
    func route(fileName: String) throws(SuiteError) -> SuiteApp {
        guard fileName.hasSuffix(".design") else { throw .unsupportedFile(name: fileName) }
        return .design
    }
    func openInTargets(for type: SuiteTypeID, from app: SuiteApp) -> [SuiteApp] {
        type == .png ? [.photo, .design].filter { $0 != app } : []
    }
    func openInRefusal(for type: SuiteTypeID, from app: SuiteApp) -> SuiteError? {
        openInTargets(for: type, from: app).isEmpty ? .noOtherReader(typeName: type.rawValue) : nil
    }
}

private struct ShapeSending: HandOffSending {
    func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt {
        SwitchReceipt(app: handOff.to, wasRunning: false, requestedAt: 2)
    }
}

private actor ShapeReceiving: HandOffReceiving {
    var settled: [String: HandOffState] = [:]
    func receive(_ data: Data, now: Date) async throws(SuiteError) -> HandOff {
        do { return try HandOffCodec.decode(data) } catch { throw .damaged("hand-off") }
    }
    func settle(id: String, as state: HandOffState) async throws(SuiteError) { settled[id] = state }
}

private struct ShapeThumbnails: ThumbnailPublishing {
    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String {
        if png.isEmpty { throw .ioFailed("empty thumbnail") }
        return "thumbnails/" + SuiteDocumentRef.fileKey(ref.fileID) + ".png"
    }
}

private struct ShapeHome: HomeBuilding {
    func home(recents: RecentsList, running: [SuiteApp], query: String, filter: SuiteApp?,
              order: [SuiteApp], missingApps: Set<SuiteApp>, missingFiles: Set<String>, now: Date) -> HomeState {
        let cards = recents.filtered(app: filter, query: query).map {
            RecentCard(item: $0, age: "Today", isMissing: missingFiles.contains($0.ref.fileID))
        }
        return HomeState(tiles: ShapeCreating().tiles(missing: missingApps), cards: cards,
                         running: order.filter(running.contains), emptyMessage: cards.isEmpty ? "No recent work yet." : nil)
    }
}

private struct ShapeHost: SuiteDocumentHost {
    func refusal(for handOff: HandOff) async -> SuiteError? {
        handOff.verb == .open ? nil : .notAvailable("Design can't do that yet.")
    }
    func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        if let reason = await refusal(for: handOff) { throw reason }
        return .accepted
    }
}

@Suite struct ContractShapeTests {
    @Test func appSwitchingCallsEveryRequirementAndItsStreamYields() async {
        let s: any AppSwitching = ShapeSwitching()
        #expect(await s.runState(of: .design) == .notRunning)
        do throws(SuiteError) {
            let receipt = try await s.switchTo(.design, reason: .home)
            #expect(receipt == SwitchReceipt(app: .design, wasRunning: false, requestedAt: 1))
        } catch { Issue.record("switchTo threw \(error.message)") }
        #expect(await s.runState(of: .design) == .running(windows: 1))
        var yielded: [Int] = []
        for await v in await s.changes() { yielded.append(v) }
        #expect(yielded == [1])
    }

    @Test func recentWorkCallsEveryRequirementAndItsStreamYields() async {
        let r: any RecentWork = ShapeRecents()
        do throws(SuiteError) {
            try await r.note(shapeRef(), event: .opened, at: shapeNow, thumbnail: "thumbnails/x.png")
            try await r.note(shapeRef("Cards.design"), event: .saved, at: shapeNow, thumbnail: nil)
            try await r.remove(fileID: shapeRef("Cards.design").fileID)
            #expect(try await r.list().items.map(\.ref.displayName) == ["Logo.design"])
            try await r.clear(app: .design)
            #expect(try await r.list().items.isEmpty)
        } catch { Issue.record("recents threw \(error.message)") }
        var yielded: [Int] = []
        for await v in await r.changes() { yielded.append(v) }
        #expect(yielded == [4])
    }

    @Test func pureContractsAnswer() {
        let c: any DocumentCreating = ShapeCreating()
        #expect(c.tiles(missing: [.design]).first?.disabledReason == SuiteError.appMissing(.design).message)
        let preset = ShapeCreating().preset
        #expect(c.handOff(for: preset, id: "h1", at: shapeNow).preset == preset)
        let routing: any DocumentRouting = ShapeRouting()
        do throws(SuiteError) {
            #expect(try routing.route(fileName: "Logo.design") == .design)
            _ = try routing.route(fileName: "notes.txt")
            Issue.record("notes.txt routed")
        } catch { #expect(error == .unsupportedFile(name: "notes.txt")) }
        #expect(routing.openInTargets(for: .png, from: .photo) == [.design])
        #expect(routing.openInRefusal(for: .png, from: .photo) == nil)
        #expect(routing.openInRefusal(for: .flareAnimation, from: .flare) == .noOtherReader(typeName: SuiteTypeID.flareAnimation.rawValue))
        let home: any HomeBuilding = ShapeHome()
        let state = home.home(recents: RecentsList(), running: [.halo, .design], query: "", filter: nil,
                              order: [.design, .halo], missingApps: [], missingFiles: [], now: shapeNow)
        #expect(state.running == [.design, .halo])
        #expect(state.emptyMessage == "No recent work yet.")
    }

    @Test func handOffContractsSendReceiveAndSettle() async {
        let sending: any HandOffSending = ShapeSending()
        let receiving: any HandOffReceiving = ShapeReceiving()
        let h = shapeHandOff()
        do throws(SuiteError) {
            #expect(try await sending.send(h).app == .design)
            let data = try HandOffCodec.encode(h)
            #expect(try await receiving.receive(data, now: shapeNow) == h)
            try await receiving.settle(id: h.id, as: .accepted)
            _ = try await receiving.receive(Data("{}".utf8), now: shapeNow)
            Issue.record("damaged hand-off received")
        } catch { #expect(error == .damaged("hand-off")) }
    }

    @Test func thumbnailsAndHostAnswer() async {
        let thumbs: any ThumbnailPublishing = ShapeThumbnails()
        let host: any SuiteDocumentHost = ShapeHost()
        do throws(SuiteError) {
            let path = try await thumbs.publish(png: Data([0x89]), for: shapeRef())
            #expect(path == "thumbnails/" + SuiteDocumentRef.fileKey(shapeRef().fileID) + ".png")
            #expect(try await host.accept(shapeHandOff()) == .accepted)
        } catch { Issue.record("threw \(error.message)") }
        #expect(await host.refusal(for: shapeHandOff()) == nil)
        do throws(SuiteError) {
            _ = try await host.accept(shapeHandOff(verb: .place))
            Issue.record("place accepted")
        } catch { #expect(error == .notAvailable("Design can't do that yet.")) }
    }
}
