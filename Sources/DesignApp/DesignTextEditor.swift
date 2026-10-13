// DesignTextEditor.swift: the inline text editor over the canvas. DesignTextOverlay is
// laid out at the artboard's size (the document at `zoom`, top-left origin) as the last
// child of the canvas overlay. While the workspace is editing a text node it shows one
// plain TextField over that node's frame; otherwise it draws nothing and takes no clicks.
// The box has no fill, only an accent hairline: the text keeps the colour it will have on
// the page (black text on a field well is unreadable in the shell's dark scheme).
//
// The field is sized in screen points (frame x zoom) and its font is the body text style's
// size x zoom, not a scaled view: AppKit's text field and its field editor do not hit-test
// or edit correctly under a scale transform. The draft goes out as `.textDraft`; Return and
// losing focus send `.commitText`, Escape sends `.cancelText`. It must take keyboard focus as
// it appears, which it can only because the canvas stops being focusable during the edit
// (DesignCanvas). The canvas does not paint the edited node's text, so nothing here
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
                DesignTextField(node: node, draft: model.textDraft, scale: scale, perform: perform)
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

    /// Screen points per document point, as CanvasLayout reads the zoom.
    private var scale: Double { zoom.isFinite && zoom > 0 ? zoom : 1 }
}

/// The text field over one node. A new node gets a new field (`.id`), which takes focus.
private struct DesignTextField: View {
    let node: DesignNode
    let draft: String
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
            // A turn after the field appears, once the canvas has stopped being focusable.
            .task { focused = true }
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
            .offset(x: node.frame.x * scale, y: node.frame.y * scale)
            .accessibilityIdentifier("design.text")
    }
}
