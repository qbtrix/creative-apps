// AfterGlowOnboardingSnapshots.swift: the welcome window (onboarding packet
// OB-5) as goldens in Golden/afterglow-onboarding/:
// afterglow-onboarding-{welcome,focus,focus-selected,start,start-default,
// start-missing,start-error}-{light,dark,light-ic,dark-ic},
// each the real OnboardingWindow over an OnboardingModel on the fakes, built
// fresh for every appearance (closing a window is Skip, which would clear the
// focus of a shared model). "start" is Photos' order, "start-default" no
// focus; "start-missing" says Halo's sample isn't in this build, "start-error"
// is a refused hand-off's sentence in place. "start-launching" (Flare's
// hand-off in flight on a sender that never answers) is checked on the model
// and shoots nothing: rendering its indeterminate ring hung the macOS job
// (#2895), so it records a known issue. A state the model can't reach yet
// (the reason OB-10 fills, the message OB-8 sets) records a known issue and
// shoots nothing, so no wrong golden is recorded; a missing golden is a known
// issue too (assertGolden), until OB-5g commits the macOS run's PNGs. The
// layout checks (blueprint 7.3) host the window through RenderBudgetWindow
// and read frames by identifier: Continue, Back and Skip sit ≥ 24 pt
// (OnboardingLayout.margin) inside the window, and no starter row's chips or
// Open sample cross the content's right edge at 720 pt and at
// SuiteSize.windowLaunch. The window bumps OnboardingWindow.bodyRuns, so the
// suite nests in BodyCountSuites and never runs beside the render budget.
// macOS only.
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import AfterGlowApp

/// A sender that never answers until cancelled, so a hand-off stays in flight (`launching`).
private actor SilentSender: HandOffSending {
    func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt {
        // Cancelling the send ends the wait at once, so no task outlives the test.
        do { try await Task.sleep(for: .seconds(600)) } catch {}
        throw .notAvailable("The test stopped waiting.")
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct AfterGlowOnboardingSnapshots {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let size = CGSize(width: OnboardingLayout.width, height: OnboardingLayout.height)
        let photosOrder: [SuiteApp] = [.library, .photo, .flare, .design, .halo]

        /// A loaded model on the fakes whose samples are all present but those `present` refuses.
        /// Documents starts empty, so an Open sample's copy has a free name and reaches the send.
        private func model(_ services: SuiteServices = .fake(),
                           present: @escaping @Sendable (String) -> Bool = { $0.hasPrefix("/fixture/Samples/") }) async -> OnboardingModel {
            let model = OnboardingModel(services: services, samplesFolder: "/fixture/Samples",
                                        documents: "/fixture/Documents", present: present,
                                        copy: { _, _ throws(SuiteError) in }, makeID: { "ob1" })
            await model.load()
            return model
        }

        /// `model` on the start page with `focus` chosen.
        private func start(_ model: OnboardingModel, focus: OnboardingFocus?) -> OnboardingModel {
            model.continue()
            if let focus { model.choose(focus) }
            model.continue()
            return model
        }

        private func shoot(_ name: String, _ make: () async -> OnboardingModel) async {
            for appearance in SnapshotAppearance.allCases {
                let model = await make()
                assertGolden(OnboardingWindow(model: model), size: size, name: "afterglow-onboarding-\(name)",
                             area: "afterglow-onboarding", appearance: appearance)
            }
        }

        @Test func onboardingStates() async {
            let welcome = await model()
            #expect(welcome.page.id == "apps")
            await shoot("welcome") { await model() }

            let focus = await model()
            focus.continue()
            #expect(focus.page.id == "focus" && focus.focus == nil)
            await shoot("focus") { let m = await model(); m.continue(); return m }

            let selected = await model()
            selected.continue()
            selected.choose(.photos)
            #expect(selected.focus == .photos)
            await shoot("focus-selected") { let m = await model(); m.continue(); m.choose(.photos); return m }

            let photos = start(await model(), focus: .photos)
            #expect(photos.page.id == "start" && photos.starters.map(\.tile.app) == photosOrder)
            await shoot("start") { start(await model(), focus: .photos) }

            let plain = start(await model(), focus: nil)
            #expect(plain.starters.map(\.tile.app) == SuiteOnboarding.order(for: nil))
            await shoot("start-default") { start(await model(), focus: nil) }
        }

        @Test func startPageStates() async {
            // Halo's sample missing: its Open sample disabled with the model's reason as its help.
            let noHalo: @Sendable (String) -> Bool = { $0.hasPrefix("/fixture/Samples/") && !$0.hasSuffix("/Intro.halo") }
            let missing = start(await model(present: noHalo), focus: nil)
            if let reason = missing.starters.first(where: { $0.tile.app == .halo })?.sampleReason {
                #expect(reason == "The Halo sample isn't in this build.")
                #expect(missing.starters.filter { $0.sampleReason != nil }.count == 1)
                await shoot("start-missing") { start(await model(present: noHalo), focus: nil) }
            } else {
                withKnownIssue("SampleCatalog.reason is OB-10's; start-missing waits on it") {
                    Issue.record("no reason for Halo's missing sample yet")
                }
            }

            // Flare's Open sample while its hand-off is in flight: checked on the model, not shot.
            var silent = SuiteServices.fake()
            silent.sending = SilentSender()
            let launching = start(await model(silent), focus: .photos)
            let send = Task { await launching.openSample(.flare, now: now) }
            for _ in 0..<100 where launching.launching == nil { try? await Task.sleep(for: .milliseconds(10)) }
            #expect(launching.launching == .flare)
            send.cancel()
            await send.value
            withKnownIssue("start-launching's indeterminate ring never settles; its shot hung the macOS job (#2895)") {
                Issue.record("no deterministic render of the launching ring yet")
            }

            // A refused hand-off: its sentence in place under the row, nothing modal.
            var refusing = SuiteServices.fake()
            refusing.sending = FakeHandOffs(unavailable: "Flare can't open documents right now.")
            let error = start(await model(refusing), focus: .photos)
            await error.openSample(.flare, now: now)
            if error.message != nil {
                await shoot("start-error") {
                    let m = start(await model(refusing), focus: .photos)
                    await m.openSample(.flare, now: now)
                    return m
                }
            } else {
                withKnownIssue("OnboardingModel.openSample sets the refused hand-off's message in OB-8") {
                    Issue.record("no message after a refused hand-off yet")
                }
            }
        }

        // MARK: Layout (blueprint 7.3)

        /// The page element names the page in its label, where a journey can read it (OJ1, OJ2).
        @Test func pageElementNamesThePage() async throws {
            let driven = await model()
            let w = RenderBudgetWindow(OnboardingWindow(model: driven), size: size)
            defer { w.close() }
            for id in ["apps", "focus", "start"] {
                try await w.settle()
                #expect(w.label(OnboardingControls.page) == id, "the page element reads \(w.label(OnboardingControls.page) ?? "nothing") on \(id)")
                driven.continue()
            }
        }

        /// Continue, Back and Skip sit at least OnboardingLayout.margin inside the window on every page.
        @Test func buttonsKeepTheirMargins() async throws {
            let margin = CGFloat(OnboardingLayout.margin)
            let driven = await model()
            // One window over the pages (closing it would Skip). Page 1: Skip, Continue.
            // Page 2: Skip, Back, Continue. Page 3: Skip, Back.
            let w = RenderBudgetWindow(OnboardingWindow(model: driven), size: size)
            defer { w.close() }
            let pages: [[String]] = [[OnboardingControls.skip, OnboardingControls.continue],
                                     [OnboardingControls.skip, OnboardingControls.back, OnboardingControls.continue],
                                     [OnboardingControls.skip, OnboardingControls.back]]
            for (index, ids) in pages.enumerated() {
                try await w.settle()
                #expect(driven.pageIndex == index)
                for id in ids {
                    let frame = try #require(await w.element(id), "no \(id) on page \(index)")
                    // Window coordinates: y grows up from the bottom edge.
                    #expect(frame.minX >= margin - 0.5 && frame.maxX <= size.width - margin + 0.5,
                            "\(id) at \(frame) on page \(index), margin \(margin)")
                    #expect(frame.minY >= margin - 0.5 && frame.maxY <= size.height - margin + 0.5,
                            "\(id) at \(frame) on page \(index), margin \(margin)")
                }
                driven.continue()
            }
        }

        /// No starter row's preset chips or Open sample cross the content's right edge.
        @Test(arguments: [CGFloat(OnboardingLayout.width), SuiteSize.windowLaunch.width])
        func startRowsFitTheContent(width: CGFloat) async throws {
            let driven = start(await model(), focus: .photos)
            let host = CGSize(width: width, height: max(size.height, SuiteSize.windowLaunch.height))
            let w = RenderBudgetWindow(OnboardingWindow(model: driven), size: host)
            defer { w.close() }
            try await w.settle()
            let content = try #require(await w.element(OnboardingControls.page), "no page element at \(width)")
            #expect(driven.starters.count == 5)
            for starter in driven.starters {
                let ids = [OnboardingControls.sample(starter.tile.app)]
                    + starter.tile.presets.prefix(3).map(OnboardingControls.preset)
                for id in ids {
                    let frame = try #require(await w.element(id), "no \(id) at \(width)")
                    #expect(frame.maxX <= content.maxX + 0.5, "\(id) ends at \(frame.maxX) past \(content.maxX) at \(width)")
                    #expect(frame.minX >= content.minX - 0.5, "\(id) starts at \(frame.minX) before \(content.minX) at \(width)")
                }
            }
        }

        /// A refusal under a row doesn't move that row: its Open sample stays level with its first chip.
        @Test func aRefusalLeavesItsRowInPlace() async throws {
            var refusing = SuiteServices.fake()
            refusing.sending = FakeHandOffs(unavailable: "Flare can't open documents right now.")
            let driven = start(await model(refusing), focus: .photos)
            let flare = try #require(driven.starters.first { $0.tile.app == .flare })
            let chip = OnboardingControls.preset(try #require(flare.tile.presets.first))
            let w = RenderBudgetWindow(OnboardingWindow(model: driven), size: size)
            defer { w.close() }
            try await w.settle()
            let before = try #require(await w.element(OnboardingControls.sample(.flare)), "no Flare Open sample")
            await driven.openSample(.flare, now: now)
            #expect(driven.failed == .flare)
            try await w.settle()
            let sample = try #require(await w.element(OnboardingControls.sample(.flare)), "no Flare Open sample")
            let first = try #require(await w.element(chip), "no \(chip)")
            #expect(abs(sample.midY - first.midY) <= 0.5, "Open sample at \(sample.midY), its first chip at \(first.midY)")
            #expect(abs(sample.midY - before.midY) <= 0.5, "Open sample moved from \(before.midY) to \(sample.midY)")
        }
    }
}
