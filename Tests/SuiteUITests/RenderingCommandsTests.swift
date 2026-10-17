// RenderingCommandsTests.swift: CH-4's checks on the Rendering menu's model.
// Three items titled Automatic, GPU (Metal) and CPU in that order with their
// ids; exactly one checked, the preference's choice; picking an item writes
// its case once; the status line reads the preference's active backend and
// shows the note only when there is one. macOS only.
import Testing

@testable import SuiteUI

@MainActor @Suite struct RenderingCommandsTests {
    @Test func threeItemsInOrderWithTheirIds() {
        let items = RenderingMenuModel(preference: FakeRenderingPreference()).items
        #expect(items.map(\.title) == ["Automatic", "GPU (Metal)", "CPU"])
        #expect(items.map(\.choice) == [.automatic, .gpu, .cpu])
        #expect(items.map(\.id) == [
            "suite.settings.rendering.automatic", "suite.settings.rendering.gpu", "suite.settings.rendering.cpu",
        ])
    }

    @Test(arguments: RenderingChoice.allCases)
    func exactlyOneItemIsCheckedAndItIsTheChoice(choice: RenderingChoice) {
        let model = RenderingMenuModel(preference: FakeRenderingPreference(choice: choice))
        let checked = model.items.filter(\.isChecked)
        #expect(checked.map(\.choice) == [choice])
        #expect(model.choice == choice)
    }

    @Test(arguments: RenderingChoice.allCases)
    func pickingAnItemSetsItsCaseOnce(picked: RenderingChoice) {
        let fake = FakeRenderingPreference(choice: picked == .cpu ? .gpu : .cpu)
        let preference = RenderingPreference(store: fake)
        let model = RenderingMenuModel(preference: preference)
        model.pick(picked)
        #expect(preference.writes == [picked])
        #expect(fake.choice == picked)
        #expect(model.items.filter(\.isChecked).map(\.choice) == [picked])
    }

    @Test func aWriteElsewhereMovesTheCheckmark() {
        let fake = FakeRenderingPreference(choice: .automatic)
        let model = RenderingMenuModel(preference: fake)
        fake.set(.cpu)
        #expect(model.choice == .cpu)
        #expect(model.items.filter(\.isChecked).map(\.choice) == [.cpu])
    }

    @Test func theStatusLineIsTheActiveBackendAndTheNoteOnlyWhenSet() {
        let fake = FakeRenderingPreference(choice: .gpu)
        let model = RenderingMenuModel(preference: fake)
        #expect(model.status == fake.status)
        #expect(model.statusLine == "Drawing on GPU")
        model.pick(.cpu)
        #expect(model.statusLine == "Drawing on CPU")

        fake.loseDevice()
        model.pick(.automatic)
        let note = fake.status.note
        #expect(note == "Drawing on CPU: Metal stopped")
        #expect(model.statusLine == note)

        #expect(RenderingMenuModel.statusLine(RenderingStatus(active: "GPU", note: nil)) == "Drawing on GPU")
        #expect(RenderingMenuModel.statusLine(RenderingStatus(active: "CPU", note: "Metal stopped")) == "Metal stopped")
    }
}
