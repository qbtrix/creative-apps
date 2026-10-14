// main.swift: a smoke run of the contracts on their fakes, so `check.sh`
// proves they compile AND behave as section 5 says, on Linux. Not shipped:
// SuiteModelTests carries the real tests (one conformance suite per contract).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

var failures = 0
@MainActor func expect(_ ok: Bool, _ what: String) { if !ok { failures += 1; print("FAIL:", what) } }

let day: Double = 86_400
let now = Date(timeIntervalSince1970: 1_800_000_000)
func ref(_ name: String, _ app: SuiteApp, _ type: SuiteTypeID) -> SuiteDocumentRef {
    SuiteDocumentRef(path: "/tmp/Documents/" + name, fileID: name, app: app, type: type, displayName: name)
}

// Recents: newest first, one per file, merge keeps the newest per file.
var list = RecentsList()
list.note(RecentItem(ref: ref("Logo.design", .design, .designDocument), lastUsed: now - 2 * day))
list.note(RecentItem(ref: ref("Bounce.flare", .flare, .flareAnimation), lastUsed: now - day))
list.note(RecentItem(ref: ref("Logo.design", .design, .designDocument), lastUsed: now))
expect(list.items.map(\.ref.displayName) == ["Logo.design", "Bounce.flare"], "recents dedupe and order")
expect(list.filtered(app: .flare, query: "").count == 1, "filter by app")
expect(list.filtered(app: nil, query: "LOGO").count == 1, "search any case")
var other = RecentsList()
other.note(RecentItem(ref: ref("Bounce.flare", .flare, .flareAnimation), lastUsed: now + day))
expect(list.merging(other).items.first?.ref.displayName == "Bounce.flare", "merge keeps newest")
var big = RecentsList()
for i in 0..<250 { big.note(RecentItem(ref: ref("f\(i).flare", .flare, .flareAnimation), lastUsed: now + Double(i))) }
expect(big.items.count == RecentsList.cap && big.items.first?.ref.displayName == "f249.flare", "cap 200")

// Routing and Open In.
let routing = FakeRouting()
expect((try? routing.route(fileName: "Cards.design")) == .design, "route design")
expect((try? routing.route(fileName: "Sunset.PNG")) == .photo, "route png to photo")
do throws(SuiteError) { _ = try routing.route(fileName: "notes.txt"); expect(false, "txt refused") }
catch { expect(error.message.contains("can't open \u{201C}notes.txt\u{201D}"), "txt message") }
expect(routing.openInTargets(for: .flareAnimation, from: .flare) == [.halo], "open in halo")
expect(routing.openInTargets(for: .png, from: .photo) == [.library], "open in library")

// Hand-off codec round trip, newer format refused.
let h = HandOff(id: "h1", from: .launcher, to: .flare, verb: .new, preset: FakeCreating.presets[.flare]?.last, createdAt: now)
let data = try HandOffCodec.encode(h)
expect((try? HandOffCodec.decode(data)) == h, "hand-off round trip")
let newer = Data("{\"format\":2}".utf8)
do throws(SuiteError) { _ = try HandOffCodec.decode(newer); expect(false, "newer refused") } catch { expect(error.message.contains("newer AfterGlow"), "newer message") }
expect(h.isExpired(now: now + 8 * day), "expires after 7 days")

// Switching and sending through the fakes.
let services = SuiteServices.fake(recents: list, running: [.design], missing: [.halo])
let r1 = try await services.switching.switchTo(.design, reason: .shortcut)
expect(r1.wasRunning, "design was running")
let r2 = try await services.sending.send(h)
expect(!r2.wasRunning && r2.app == .flare, "cold send launches flare")
do throws(SuiteError) { _ = try await services.switching.switchTo(.halo, reason: .home); expect(false, "halo missing") }
catch { expect(error == .appMissing(.halo), "missing app error") }

// Home: order, missing tile, empty message, filter.
let home = services.home.home(recents: list, running: [.launcher, .design], query: "", filter: nil,
                              order: [.library, .photo, .flare, .design, .halo], missingApps: [.halo], missingFiles: ["Logo.design"], now: now)
expect(home.tiles.map(\.app) == [.library, .photo, .flare, .design, .halo], "tile order")
expect(home.tiles.last?.disabledReason?.hasPrefix("Halo is missing") == true, "missing tile reason")
expect(home.cards.first?.isMissing == true && home.cards.first?.age == "Today", "missing card")
expect(home.running == [.design], "running strip")
let emptyHome = services.home.home(recents: RecentsList(), running: [], query: "", filter: nil, order: SuiteApp.apps,
                                   missingApps: [], missingFiles: [], now: now)
expect(emptyHome.emptyMessage?.hasPrefix("No recent work yet") == true, "empty home")
expect(HomeLayout.columns(windowWidth: 880) == 3 && HomeLayout.columns(windowWidth: 1728) >= 7, "home columns")

// Pasteboard: Design art into Flare, image into Flare refused, colour exact, damaged falls back.
let pb = FakePasteboard()
let blue = SuiteColorValue(space: .displayP3, red: 0.1, green: 0.4, blue: 0.9)
let art = AssetEnvelope(name: "Card", kind: .vector, from: .design, color: blue, svg: "<svg/>")
let reps = pb.representations(of: .envelope(art))
expect(pb.bestItem(from: reps, for: .flare) == .envelope(art), "flare takes the envelope")
let png = [TypedData(type: .png, data: Data([0x89, 0x50]))]
expect(pb.pasteRefusal(for: png, in: .flare)?.message == "Flare can't paste images yet.", "flare refuses images")
expect(pb.pasteRefusal(for: [], in: .photo) == .nothingToPaste, "nothing to paste")
let damaged = [TypedData(type: .assetEnvelope, data: Data("{".utf8)), TypedData(type: .svg, data: Data("<svg/>".utf8))]
expect(pb.bestItem(from: damaged, for: .flare) == .vector(svg: "<svg/>", name: "Pasted art"), "damaged envelope falls back to svg")
expect(blue.hex == "1A66E6", "hex")

// Assets and links.
let assets = FakeAssets()
let a = try await assets.add(AssetDraft(kind: .vector, name: "Logo", payload: Data("<svg/>".utf8), payloadExtension: "svg"), id: "a1", at: now)
let link = FakeLinking().link(to: a)
expect(FakeLinking().status(of: link, in: try await assets.index()) == .current, "link current")
_ = try await assets.update("a1", payload: Data("<svg v2/>".utf8), color: nil, at: now + 1)
let idx = try await assets.index()
expect(FakeLinking().status(of: link, in: idx) == .updateAvailable(revision: 2), "update available")
expect(FakeLinking().updated(link, in: idx)?.placedRevision == 2, "updated link")
try await assets.remove("a1")
expect(FakeLinking().status(of: link, in: try await assets.index()) == .missing, "missing")
let merged = AssetIndex(revision: 1, assets: [a]).merging(idx)
expect(merged.asset("a1")?.revision == 2, "index merge keeps higher revision")

// Round trip.
let rt = FakeRoundTrips()
let src = RoundTripSource(catalogPhotoID: "p2", original: ref("IMG_0002.jpg", .library, .jpeg))
let s = try await rt.begin(src, id: "r1", at: now)
expect(s.title == "IMG_0002 (Library edit)", "round trip title")
do throws(SuiteError) { _ = try await rt.returned(session: "r1", as: ref("x.png", .library, .png)); expect(false, "return before save refused") } catch {}
_ = try await rt.photoSaved(session: "r1", flattened: ref("IMG_0002 edit 1.png", .photo, .png), layered: ref("IMG_0002 edit 1.ora", .photo, .photoOpenRaster))
let back = try await rt.returned(session: "r1", as: ref("IMG_0002 edit 1.png", .library, .png))
if case .returned = back.state {} else { expect(false, "returned state") }

// Preferences: stale revision refused.
let prefs = FakePreferences()
var p = try await prefs.load()
p.units = .centimeters
let saved = try await prefs.save(p)
expect(saved.revision == 1, "revision bumps")
do throws(SuiteError) { _ = try await prefs.save(p); expect(false, "stale refused") } catch { expect(error == .staleRevision, "stale error") }
expect(SuitePreferences(autosaveSeconds: 2).autosaveSeconds == 10, "autosave clamp")

// Onboarding.
let ob = FakeOnboarding()
expect(ob.shouldShow(SuitePreferences(), version: 1), "show first time")
let done = ob.finishing(SuitePreferences(), focus: .photos, version: 1)
expect(!ob.shouldShow(done, version: 1) && done.homeOrder.prefix(2) == [.library, .photo], "photos first")

// Updates.
let feed = Data("""
[{"version":{"major":1,"minor":2,"patch":0},"notes":"Faster switching","url":"https://example.org/a.zip","byteCount":1,"signature":"good","minimumSystem":"26.0"},
 {"version":{"major":1,"minor":1,"patch":0},"notes":"","url":"https://example.org/b.zip","byteCount":1,"signature":"good","minimumSystem":"26.0"}]
""".utf8)
let up = FakeUpdates(feed: feed, validSignatures: ["good"])
let offer = try await up.check(current: SuiteVersion(1, 1, 0))
expect(offer?.version == SuiteVersion(1, 2, 0), "newest offer")
expect(try await up.check(current: SuiteVersion(1, 2, 0)) == nil, "up to date")
expect(SuiteVersion("1.10") ?? SuiteVersion(0, 0, 0) > SuiteVersion(1, 9, 9), "version compare")
var bad = offer
bad?.signature = "forged"
if let bad { do throws(SuiteError) { _ = try await up.download(bad); expect(false, "forged refused") } catch { expect(error == .updateNotVerified, "verify") } }

// Size budget.
let report = SizeReport(commit: "abc", entries: [SizeEntry(name: "Flare", kind: .executable, bytes: 3_000_000),
                                               SizeEntry(name: "AfterGlow.app", kind: .wholeBundle, bytes: 20_000_000)],
                        suiteUISymbols: ["Flare": 4300, "Design": 0])
let findings = FakeSizeBudget().evaluate(report, against: SizeBudget(limits: ["Flare": 2_000_000, "AfterGlow.app": 30_000_000]))
expect(findings.map(\.name) == ["Flare", "Flare SuiteUI symbols"], "size findings")

// Registry and identity.
expect(SuiteApp.flare.bundleID == "org.creativesuite.flare" && SuiteApp.launcher.bundleID == "org.creativesuite.afterglow", "bundle ids")
expect(SuiteApp.halo.bundlePath == "Contents/Helpers/Halo.app", "bundle path")
expect(Set(SuiteApp.allCases.map(\.switchDigit)).count == 6, "switch digits unique")

print(failures == 0 ? "contracts: PASS" : "contracts: \(failures) FAILED")
if failures > 0 { fatalError("contracts failed") }
