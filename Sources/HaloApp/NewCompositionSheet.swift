// NewCompositionSheet.swift: the sheet New Composition opens: name, width,
// height, frame rate and duration in seconds, in a system Form. The sheet owns
// only its draft (presentation state). The numeric fields bind through text
// (HaloModel's CompositionDraft), so validation and Create always see the
// latest keystroke, not the value from the last Return or focus change.
// CompositionSettings says what is valid and why not, and Create stays
// disabled until it is. Each problem shows right under the field it's about
// (CompositionDraft.problems(for:)), in stateError with the error circle.
// Width and Height end in "px", their unit. Create hands the settings to
// `onCreate`; the window turns them into a composition. Each field's
// accessibility label is its column label (the columns form draws the title
// apart from the field, #286) and every control has a
// `halo.composition.sheet.*` identifier (#290).
import HaloModel
import SuiteUI
import SwiftUI

struct NewCompositionSheet: View {
    var onCreate: @MainActor (CompositionSettings) -> Void
    var onCancel: @MainActor () -> Void
    @State private var draft: CompositionDraft

    init(
        settings: CompositionSettings, onCreate: @escaping @MainActor (CompositionSettings) -> Void = { _ in },
        onCancel: @escaping @MainActor () -> Void = {}
    ) {
        self._draft = State(initialValue: CompositionDraft(settings))
        self.onCreate = onCreate
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text("New Composition").font(SuiteFont.title)
            Form {
                row("Name", field: .name) {
                    TextField("Name", text: $draft.name)
                        .labelsHidden()
                        .accessibilityLabel("Name")
                        .haloControl(id: "halo.composition.sheet.name", enabled: true, help: nil)
                }
                row("Width", field: .width) {
                    HStack(spacing: SuiteSpacing.s) {
                        TextField("Width", text: $draft.widthText)
                            .labelsHidden()
                            .accessibilityLabel("Width")
                            .haloControl(id: "halo.composition.sheet.width", enabled: true, help: nil)
                        Text(HaloComposition.sizeUnit)
                    }
                }
                row("Height", field: .height) {
                    HStack(spacing: SuiteSpacing.s) {
                        TextField("Height", text: $draft.heightText)
                            .labelsHidden()
                            .accessibilityLabel("Height")
                            .haloControl(id: "halo.composition.sheet.height", enabled: true, help: nil)
                        Text(HaloComposition.sizeUnit)
                    }
                }
                row("Frame Rate", field: .frameRate) {
                    Picker("Frame Rate", selection: $draft.framesPerSecond) {
                        ForEach(CompositionSettings.frameRates, id: \.self) { Text("\($0) fps").tag($0) }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Frame Rate")
                    .haloControl(id: "halo.composition.sheet.frameRate", enabled: true, help: nil)
                }
                row("Duration (seconds)", field: .duration) {
                    TextField("Duration (seconds)", text: $draft.durationText)
                        .labelsHidden()
                        .accessibilityLabel("Duration (seconds)")
                        .haloControl(id: "halo.composition.sheet.duration", enabled: true, help: nil)
                }
            }
            .formStyle(.columns)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                    .haloControl(id: "halo.composition.sheet.cancel", enabled: true, help: nil)
                Button("Create") { if draft.isValid { onCreate(draft.settings) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
                    .help(createHelp)
                    .haloControl(id: "halo.composition.sheet.create", enabled: draft.isValid, help: createHelp)
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentMinimum.width)
    }

    /// One form row: `title` in the label column, the control, then the
    /// problems about `field` right under it.
    private func row<Control: View>(
        _ title: String, field: CompositionField, @ViewBuilder control: () -> Control
    ) -> some View {
        LabeledContent(title) {
            VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                control()
                ForEach(draft.problems(for: field), id: \.self) { problem in
                    // An error, not a warning: stateError with the circle, like HaloRefusalCaption.
                    Label(problem, systemImage: "exclamationmark.circle")
                        .font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.stateError)
                }
            }
        }
    }

    /// Create's tooltip: the first problem while the settings can't be used.
    private var createHelp: String {
        draft.isValid ? "Create the composition" : draft.problems.first ?? "Fix the settings above to create it."
    }
}
