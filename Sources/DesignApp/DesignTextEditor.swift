// DesignTextEditor.swift: the inline text editor over the canvas. DesignTextOverlay is
// laid out at the artboard's size (the document at `zoom`, top-left origin) as the last
// child of the canvas overlay. While the workspace is editing a text node it shows one
// plain TextField over that node's frame; otherwise it draws nothing and takes no clicks.
// The box has no fill, only an accent hairline: the text keeps the colour it will have on
// the page (black text on a field well is unreadable in the shell's dark scheme).
//
// The field sits over the node's frame at the canvas zoom (`box`), in the node's own font
// (DesignTextFont, the one the canvas artwork draws with) at its size x
// DesignWorkspace.textEditScale, which is the zoom itself, and with its alignment, so the
// text being typed is the text that commits and nothing jumps on Return (#268). Sized, not a
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
                DesignTextField(node: node, draft: model.textDraft, zoom: zoom, perform: perform)
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

    /// The editor's box over `node` at `zoom`, in view points: the node's frame at the zoom, the
    /// rect the artwork draws the committed text in.
    static func box(for node: DesignNode, zoom: Double) -> CGRect {
        let scale = DesignWorkspace.textEditScale(zoom: zoom)
        return node.frame.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    /// The editor's point size for `node` at `zoom`: the style's size times the zoom.
    static func fontSize(for node: DesignNode, zoom: Double) -> Double {
        DesignTextFont.pointSize(node.textStyle, scale: DesignWorkspace.textEditScale(zoom: zoom))
    }
}

/// The text field over one node at `zoom`. A new node gets a new field (`.id`), which takes focus.
private struct DesignTextField: View {
    let node: DesignNode
    let draft: String
    let zoom: Double
    let perform: DesignPerform
    @FocusState private var focused: Bool

    var body: some View {
        let style = node.textStyle
        let box = DesignTextOverlay.box(for: node, zoom: zoom)
        TextField("Text", text: Binding(get: { draft }, set: { perform(.textDraft($0)) }))
            .textFieldStyle(.plain)
            .labelsHidden()
            .font(DesignTextFont.font(style, scale: DesignWorkspace.textEditScale(zoom: zoom)))
            .multilineTextAlignment(DesignTextFont.textAlignment(style))
            .foregroundStyle(node.fill.color)
            .focused($focused)
            .task { await takeFocus() }
            .onSubmit { perform(.commitText) }
            .onExitCommand { perform(.cancelText) }
            .onChange(of: focused) { _, isFocused in if !isFocused { perform(.commitText) } }
            .frame(width: box.width, height: box.height, alignment: DesignTextFont.frameAlignment(style))
            .border(SuiteColor.accent)
            // A press on the box beside the text must not reach the canvas drag beneath, which
            // would place another text node. The field itself takes its own clicks.
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0))
            .offset(x: box.minX, y: box.minY)
            .accessibilityIdentifier("design.text")
    }

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
