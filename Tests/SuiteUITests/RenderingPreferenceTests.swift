// RenderingPreferenceTests.swift: CH-2's checks. RenderingChoice reads only
// its three raw values ("metal" is not one), the stubbed RenderingPreference
// answers with its fake's values and records every write (a repeat included),
// the control ids are the packet's, and the gallery declares the canvas-host
// and settings-rendering pages, so SJ0 opens both from the index. macOS only.
import Combine
import Foundation
import Testing

@testable import SuiteUI

@MainActor @Suite struct RenderingPreferenceTests {
    @Test func choiceDecodesItsThreeRawValuesAndRejectsMetal() throws {
        #expect(RenderingPreference.decode("automatic") == .automatic)
        #expect(RenderingPreference.decode("gpu") == .gpu)
        #expect(RenderingPreference.decode("cpu") == .cpu)
        #expect(RenderingPreference.decode("metal") == nil)
        #expect(RenderingPreference.decode("") == nil)
        #expect(RenderingPreference.decode(nil) == nil)

        let decoded = try JSONDecoder().decode([RenderingChoice].self, from: Data(#"["automatic","gpu","cpu"]"#.utf8))
        #expect(decoded == [.automatic, .gpu, .cpu])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([RenderingChoice].self, from: Data(#"["metal"]"#.utf8))
        }
    }

    @Test func theStubbedStoreReturnsTheFakesValues() {
        let fake = FakeRenderingPreference(choice: .gpu)
        let preference = RenderingPreference(store: fake)
        #expect(preference.choice == .gpu)
        #expect(preference.status == fake.status)

        fake.loseDevice()
        preference.set(.automatic)
        #expect(fake.choice == .automatic)
        #expect(preference.choice == fake.choice)
        #expect(preference.status == fake.status)
        #expect(preference.status.note != nil)
    }

    @Test func setRecordsEveryWriteARepeatIncluded() {
        let preference = RenderingPreference(store: FakeRenderingPreference(choice: .automatic))
        let heard = HeardRenderingChoices()
        let token = preference.observe { heard.choices.append($0) }
        preference.set(.gpu)
        preference.set(.gpu)
        preference.set(.cpu)
        #expect(preference.writes == [.gpu, .gpu, .cpu])
        #expect(heard.choices == [.gpu, .gpu, .cpu])
        #expect(preference.choice == .cpu)
        token.cancel()
    }

    @Test func theKeyAndControlIdsAreThePackets() {
        #expect(RenderingPreference.key == "suite.rendering")
        #expect(RenderingControlID.canvas == "suite.canvas")
        #expect(RenderingControlID.overlay == "suite.canvas.overlay")
        #expect(RenderingControlID.menu == "suite.menu.rendering")
        #expect(RenderingControlID.status == "suite.settings.rendering.status")
        #expect(RenderingChoice.allCases.map(RenderingControlID.item) == [
            "suite.settings.rendering.automatic", "suite.settings.rendering.gpu", "suite.settings.rendering.cpu",
        ])
    }

    /// SJ0 opens every page the index lists, and the index lists `SuiteGallery.pageNames`.
    @Test func theGalleryDeclaresBothPages() {
        for page in [GalleryCanvasHost.name, GalleryRenderingPane.name] {
            #expect(SuiteGallery.pageNames.contains(page))
            #expect(SuiteGallery.resolve(page) == .page(page))
        }
        #expect(GalleryCanvasHost.name == "canvas-host")
        #expect(GalleryRenderingPane.name == "settings-rendering")
    }
}

@MainActor private final class HeardRenderingChoices {
    var choices: [RenderingChoice] = []
}
