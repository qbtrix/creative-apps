// DesignTextEditor.swift: the inline text editor over the canvas. DesignTextOverlay is
// laid out at the artboard's size (the document at `zoom`, top-left origin) as the last
// child of the canvas overlay. While the workspace is editing a text node it shows one
// plain TextField over that node's frame; otherwise it draws nothing and takes no clicks.
// The box has no fill, only an accent hairline: the text keeps the colour it will have on
// the page (black text on a field well is unreadable in the shell's dark scheme).
//
// The field sits at the node's top-left at the canvas zoom, but its size (frame x scale) and
// font (the body text style's size x scale) use DesignWorkspace.textEditScale, the zoom but
// never under 1, so the text being typed reads even on a zoomed-out page. Sized, not a
// scaled view: AppKit's text field and its field editor do not hit-test or edit correctly
// under a scale transform. The draft goes out as `.textDraft`; Return and
// losing focus send `.commitText`, Escape sends `.cancelText`. It asks for keyboard focus as
// it appears (takeFocus), and the canvas stops being focusable during the edit so it can't
// hold the keys (DesignCanvas). The canvas does not paint the edited node's text, so nothing here
// repeats it. Presentation state only: focus.
import AppKit
import DesignModel
import SuiteUI
import SwiftUI

struct DesignTextOverlay: View {
    let model: DesignWorkspace
    let zoom: Double
    var perform: DesignPerform = { _ in }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let node = editing {
                DesignTextField(
                    node: node, draft: model.textDraft, zoom: zoom, scale: DesignWorkspace.textEditScale(zoom: zoom),
                    perform: perform)
                    .id(node.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(editing != nil)
    }

    /// The node being edited. Starting an edit selects it, and moving the selection ends the
    /// edit, so it is always the selected node.
    private var editing: DesignNode? {
        guard let id = model.editingTextID, let node = model.selectedNode, node.id == id else { return nil }
        return node
    }
}

/// The text field over one node, at `zoom` and drawn at `scale`. A new node gets a new field
/// (`.id`), which takes focus.
private struct DesignTextField: View {
    let node: DesignNode
    let draft: String
    let zoom: Double
    let scale: Double
    let perform: DesignPerform
    @FocusState private var focused: Bool

    private static let bodyPoints = NSFont.preferredFont(forTextStyle: .body).pointSize

    var body: some View {
        TextField("Text", text: Binding(get: { draft }, set: { perform(.textDraft($0)) }))
            .textFieldStyle(.plain)
            .labelsHidden()
            .font(.system(size: Self.bodyPoints * scale))
            .foregroundStyle(node.fill.color)
            .focused($focused)
            .task { await takeFocus() }
            .onSubmit { perform(.commitText) }
            .onExitCommand { perform(.cancelText) }
            .onChange(of: focused) { _, isFocused in if !isFocused { perform(.commitText) } }
            .padding(.horizontal, SuiteSpacing.xxs)
            .frame(width: node.frame.width * scale, height: node.frame.height * scale, alignment: .topLeading)
            .border(SuiteColor.accent)
            // A press on the box beside the text must not reach the canvas drag beneath, which
            // would place another text node. The field itself takes its own clicks.
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0))
            .offset(x: node.frame.x * origin, y: node.frame.y * origin)
            .accessibilityIdentifier("design.text")
    }

    /// Screen points per document point for the field's position, as CanvasLayout reads the zoom.
    private var origin: Double { zoom.isFinite && zoom > 0 ? zoom : 1 }

    /// Asks for the keyboard until the field has it. A request made as the field appears is
    /// refused (the journey's typing went nowhere until it clicked the box), so it asks again.
    /// ponytail: polls for up to a third of a second; replace with a focus API that waits for
    /// the field once SwiftUI has one.
    private func takeFocus() async {
        for _ in 0..<10 where !focused && !Task.isCancelled {
            focused = true
            try? await Task.sleep(for: .milliseconds(30))
        }
    }
}
