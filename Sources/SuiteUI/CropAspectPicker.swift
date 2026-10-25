// CropAspectPicker.swift (orientation-crop OC-5): ChoiceChips for each crop aspect, Custom W and H fields, and a
// landscape/portrait toggle on X; each sends a CropPick naming its crop.* command (rules: CropAspectChoices).
import SuiteKernel
import SwiftUI

public struct CropAspectPicker: View {
    nonisolated static let chips = CropAspectChoice.allCases.map { InspectorOption(id: $0, title: $0.title, identifier: $0.identifier) }
    nonisolated static let toggleCommand = CropAspectChoices.swapCommand

    /// Whether the orientation toggle acts on `aspect`, and its tooltip: the command, or why not.
    nonisolated static func toggleHelp(_ aspect: CropAspect) -> (enabled: Bool, text: String) {
        CropAspectChoices.swapHelp(aspect).map { (false, $0) } ?? (true, "Turns the crop between landscape and portrait (X): \(toggleCommand)")
    }

    private let aspect: CropAspect, orientation: CropOrientation, onPick: @MainActor (CropPick) -> Void
    @State private var editingCustom = false
    @State private var width = ""
    @State private var height = ""

    public init(aspect: CropAspect, orientation: CropOrientation, onPick: @escaping @MainActor (CropPick) -> Void) {
        (self.aspect, self.orientation, self.onPick) = (aspect, orientation, onPick)
    }

    public var body: some View {
        let (toggle, portrait) = (Self.toggleHelp(aspect), orientation == .portrait)
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ChoiceChips(options: Self.chips, selected: editingCustom ? .custom : CropAspectChoice.chip(for: aspect), onSelect: choose)
                .help("Locks the crop to a shape: \(CropAspectChoices.aspectCommand)")
            if editingCustom || CropAspectChoice.chip(for: aspect) == .custom { custom }
            Button { onPick(CropPick(command: Self.toggleCommand, aspect: aspect, orientation: portrait ? .landscape : .portrait)) } label: {
                Label(portrait ? "Portrait" : "Landscape", systemImage: portrait ? "rectangle.portrait" : "rectangle")
            }
            .keyboardShortcut("x", modifiers: []).disabled(!toggle.enabled).help(toggle.text)
            .suiteControl(id: "suite.crop.orientation", enabled: toggle.enabled, reason: toggle.enabled ? nil : toggle.text)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("suite.crop")
    }

    private var custom: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xxs) {
            HStack(spacing: SuiteSpacing.xs) {
                field("W", text: width, id: "suite.crop.custom-width") { width = $0 }
                Text(":").foregroundStyle(SuiteColor.textSecondary)
                field("H", text: height, id: "suite.crop.custom-height") { height = $0 }
            }
            if case .problem(let problem) = CropAspectChoices.custom(width: width, height: height), !(width + height).isEmpty {
                Label(problem, systemImage: "exclamationmark.circle").font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.stateError).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("suite.crop.custom-problem")
            }
        }
    }

    private func field(_ title: String, text: String, id: String, set: @escaping (String) -> Void) -> some View {
        TextField(title, text: Binding(get: { text }, set: { set($0); sendCustom() }))
            .textFieldStyle(.roundedBorder).labelsHidden().frame(width: SuiteSize.inspectorField)
            .help("A whole number from 1 to \(CropAspectChoices.largestSide): \(CropAspectChoices.aspectCommand)")
            .accessibilityLabel(title).accessibilityIdentifier(id)
    }

    private func choose(_ chip: CropAspectChoice) {
        editingCustom = chip == .custom
        guard let picked = chip.aspect else { sendCustom(); return }
        onPick(CropPick(command: chip.command, aspect: picked, orientation: orientation))
    }

    private func sendCustom() {
        guard case .aspect(let typed) = CropAspectChoices.custom(width: width, height: height) else { return }
        onPick(CropPick(command: CropAspectChoices.aspectCommand, aspect: typed,
                        orientation: CropAspectChoices.orientation(of: typed, else: orientation)))
    }
}
