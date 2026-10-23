// PhotoWindow+Text.swift: the Type tool's area of a Photo window (text-layers TX-3): its intents, their
// route, and PhotoTextBoxOverlay, the field over the canvas while the Type tool has a box open. A click
// with the Type tool opens the box (PhotoWorkspace.endDrag); the field sends what is typed as `.type`,
// Return and losing focus `.commit`, Escape `.cancel`. Until TX-5 builds `text.add` a commit adds
// nothing and the status line says why. Presentation state only: focus.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// What the Type tool's box can be asked to do.
enum TypeIntent {
    /// The open box's words become these.
    case type(String)
    /// Adds the box's words as a text layer and closes it.
    case commit
    /// Closes the box and drops its words.
    case cancel
    /// Restyles the selected text layer: one text inspector gesture (PhotoTextInspector).
    case style(TextIntent)
}

extension PhotoWindow {
    func performType(_ intent: TypeIntent) {
        switch intent {
        case .type(let words): model.typeText(words)
        case .commit: model.commitTextBox()
        case .cancel: model.cancelTextBox()
        case .style(let intent): model.runText(intent)
        }
    }
}

/// The Type tool's field at its box's origin, at `zoom`; nothing, and no clicks, with no box open.
struct PhotoTextBoxOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double
    var perform: PhotoPerform = { _ in }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let box = model.textBox {
                PhotoTextBoxField(draft: box.draft, perform: perform)
                    .offset(x: box.origin.x * zoom, y: box.origin.y * zoom)
                    .id("\(box.origin.x),\(box.origin.y)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(model.textBox != nil)
    }
}

/// The field of one box. A new box gets a new field (`.id`), which takes focus.
private struct PhotoTextBoxField: View {
    let draft: String
    let perform: PhotoPerform
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Text", text: Binding(get: { draft }, set: { perform(.text(.type($0))) }))
            .textFieldStyle(.plain)
            .labelsHidden()
            .font(SuiteFont.title)
            .fixedSize()
            .padding(SuiteSpacing.xs)
            .border(SuiteColor.accent)
            .focused($focused)
            .task { await takeFocus() }
            .onSubmit { perform(.text(.commit)) }
            .onExitCommand { perform(.text(.cancel)) }
            .onChange(of: focused) { _, isFocused in if !isFocused { perform(.text(.commit)) } }
            .accessibilityIdentifier("photo.text.box")
    }

    /// Asks for the keyboard until the field has it: a request made as the field appears can be refused.
    /// ponytail: polls for up to a third of a second, as DesignTextEditor's field does.
    private func takeFocus() async {
        for _ in 0..<10 where !focused && !Task.isCancelled {
            focused = true
            try? await Task.sleep(for: .milliseconds(30))
        }
    }
}
