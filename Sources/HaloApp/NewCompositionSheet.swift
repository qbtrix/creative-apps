// NewCompositionSheet.swift: the sheet New Composition opens: name, width,
// height, frame rate and duration in seconds, in a system Form. The sheet owns
// only its draft (presentation state); HaloModel's CompositionSettings says
// what is valid and why not, and Create stays disabled until it is. Create
// hands the draft to `onCreate`; the window turns it into a composition.
import HaloModel
import SuiteUI
import SwiftUI

struct NewCompositionSheet: View {
    var onCreate: @MainActor (CompositionSettings) -> Void
    var onCancel: @MainActor () -> Void
    @State private var settings: CompositionSettings

    init(
        settings: CompositionSettings, onCreate: @escaping @MainActor (CompositionSettings) -> Void = { _ in },
        onCancel: @escaping @MainActor () -> Void = {}
    ) {
        self._settings = State(initialValue: settings)
        self.onCreate = onCreate
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text("New Composition").font(SuiteFont.title)
            Form {
                TextField("Name", text: $settings.name)
                TextField("Width", value: $settings.width, format: .number)
                TextField("Height", value: $settings.height, format: .number)
                Picker("Frame Rate", selection: $settings.framesPerSecond) {
                    ForEach(CompositionSettings.frameRates, id: \.self) { Text("\($0) fps").tag($0) }
                }
                TextField("Duration (seconds)", value: $settings.durationSeconds, format: .number)
            }
            .formStyle(.columns)
            ForEach(settings.problems, id: \.self) { problem in
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { onCreate(settings) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!settings.isValid)
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentMinimum.width)
    }
}
