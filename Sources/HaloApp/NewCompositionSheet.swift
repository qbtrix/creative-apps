// NewCompositionSheet.swift: the sheet New Composition opens: name, width,
// height, frame rate and duration in seconds, in a system Form. The sheet owns
// only its draft (presentation state). The numeric fields bind through text
// (HaloModel's CompositionDraft), so validation and Create always see the
// latest keystroke, not the value from the last Return or focus change.
// CompositionSettings says what is valid and why not, and Create stays
// disabled until it is. Create hands the settings to `onCreate`; the window
// turns them into a composition.
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
                TextField("Width", text: $draft.widthText)
                TextField("Height", text: $draft.heightText)
                Picker("Frame Rate", selection: $draft.framesPerSecond) {
                    ForEach(CompositionSettings.frameRates, id: \.self) { Text("\($0) fps").tag($0) }
                }
                TextField("Duration (seconds)", text: $draft.durationText)
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
                Button("Create") { if draft.isValid { onCreate(draft.settings) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentMinimum.width)
    }
}
