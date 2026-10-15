// NewCompositionSheet.swift: the sheet New Composition opens: name, width,
// height, frame rate and duration in seconds, in a system Form. The sheet owns
// only its draft (presentation state). The numeric fields bind through text
// (HaloModel's CompositionDraft), so validation and Create always see the
// latest keystroke, not the value from the last Return or focus change.
// CompositionSettings says what is valid and why not, and Create stays
// disabled until it is. Create hands the settings to `onCreate`; the window
// turns them into a composition. Each field's accessibility label is its
// column label (the columns form draws the title apart from the field, #286)
// and every control has a `halo.composition.sheet.*` identifier (#290).
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
                TextField("Name", text: $draft.name)
                    .accessibilityLabel("Name")
                    .haloControl(id: "halo.composition.sheet.name", enabled: true, help: nil)
                TextField("Width", text: $draft.widthText)
                    .accessibilityLabel("Width")
                    .haloControl(id: "halo.composition.sheet.width", enabled: true, help: nil)
                TextField("Height", text: $draft.heightText)
                    .accessibilityLabel("Height")
                    .haloControl(id: "halo.composition.sheet.height", enabled: true, help: nil)
                Picker("Frame Rate", selection: $draft.framesPerSecond) {
                    ForEach(CompositionSettings.frameRates, id: \.self) { Text("\($0) fps").tag($0) }
                }
                .accessibilityLabel("Frame Rate")
                .haloControl(id: "halo.composition.sheet.frameRate", enabled: true, help: nil)
                TextField("Duration (seconds)", text: $draft.durationText)
                    .accessibilityLabel("Duration (seconds)")
                    .haloControl(id: "halo.composition.sheet.duration", enabled: true, help: nil)
            }
            .formStyle(.columns)
            ForEach(draft.problems, id: \.self) { problem in
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
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

    /// Create's tooltip: the first problem while the settings can't be used.
    private var createHelp: String {
        draft.isValid ? "Create the composition" : draft.problems.first ?? "Fix the settings above to create it."
    }
}
