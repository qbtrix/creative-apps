// HomeGridPreviewTests.swift: the home's Recent cards show their documents'
// previews (shared-thumbnails ST-3) in a real window on FakeThumbnails: three
// previews and a mark, no blank card, one ask per card however many bodies run.
// HomePreviewFixture is shared with the ST-4 tests. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import AfterGlowApp

/// FakeThumbnails that records each `preview(for:)`.
actor AskingThumbnails: ThumbnailPublishing {
    let inner: FakeThumbnails
    private(set) var asked: [String] = []
    init(seeded: [SuiteDocumentRef]) { inner = FakeThumbnails(seeded: seeded) }
    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String { try await inner.publish(png: png, for: ref) }
    func preview(for ref: SuiteDocumentRef) async -> Data? { asked.append(ref.fileID); return await inner.preview(for: ref) }
}

@MainActor enum HomePreviewFixture {
    static let apps: [(String, SuiteApp)] = [("ora", .photo), ("design", .design), ("flare", .flare), ("halo", .halo)]

    /// `count` documents, one app after another.
    static func refs(_ count: Int) -> [SuiteDocumentRef] {
        (0..<count).map { n in
            let (ext, app) = apps[n % apps.count], path = "/fixture/Doc \(n).\(ext)"
            return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app,
                                    type: SuiteTypeID(rawValue: "public.data"), displayName: "Doc \(n).\(ext)")
        }
    }

    /// A reloaded home on `refs`, every file present, previews read from `thumbnails`.
    static func model(_ refs: [SuiteDocumentRef], thumbnails: any ThumbnailPublishing) async -> (HomeModel, SuiteServices) {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = refs.enumerated().map { RecentItem(ref: $1, lastUsed: now.addingTimeInterval(-60 * Double($0 + 1))) }
        var services = SuiteServices.fake(recents: RecentsList(revision: 1, items: items))
        services.thumbnails = thumbnails
        let model = HomeModel(services: services, fileExists: { _ in true }, makeID: { "h1" })
        await model.reload(now: now)
        return (model, services)
    }

    static func grid(_ model: HomeModel, _ services: SuiteServices, previews: HomePreviews<Image>) -> HomeGrid {
        HomeGrid(model: model, images: [:], isPreview: false,
                 open: HomeContent.open(services, identifier: "afterglow.home.empty.open"), loaded: previews)
    }

    static let bodies = { () -> Int? in
        #if DEBUG
        return HomeGrid.bodyRuns
        #else
        return nil
        #endif
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct HomeGridPreviewTests {
        @Test(.timeLimit(.minutes(1))) func threePreviewsAMarkAndOneAskPerCard() async throws {
            let refs = HomePreviewFixture.refs(4)
            let thumbnails = AskingThumbnails(seeded: Array(refs.prefix(3)))
            let (model, services) = await HomePreviewFixture.model(refs, thumbnails: thumbnails)
            let previews = HomeGrid.previews()
            let w = RenderBudgetWindow(HomePreviewFixture.grid(model, services, previews: previews), size: CGSize(width: 900, height: 600))
            defer { w.close() }
            try await w.settle(untilStable: HomePreviewFixture.bodies)
            // More bodies: each selection runs the grid's body again; none may ask again.
            let before = HomePreviewFixture.bodies()
            for ref in refs + refs {
                model.select(ref.fileID)
                try await w.settle(untilStable: HomePreviewFixture.bodies, turns: 2)
            }
            if let before, let after = HomePreviewFixture.bodies() { #expect(after > before, "selecting ran no body") }
            #expect(await thumbnails.asked.sorted() == refs.map(\.fileID).sorted(), "a card asked more than once, or never")
            #expect(previews.requests == refs.count)

            let cards = model.state.cards
            #expect(cards.map { previews.kind(for: $0.item.ref) } == [.preview, .preview, .preview, .mark])
            let items = cards.map { HomeGrid.item($0, images: [:], previews: previews) }
            #expect(items.allSatisfy { $0.image != nil }, "a card is blank")
            // After the age, the card says what its picture is.
            #expect(items.map { $0.accessibilityValue?.split(separator: ",").last.map(String.init) }
                == [" preview", " preview", " preview", " app mark"])
            #expect(previews.pictures.count == 3)
        }
    }
}
#endif
