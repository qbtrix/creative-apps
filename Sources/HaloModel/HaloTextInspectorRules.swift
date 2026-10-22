// HaloTextInspectorRules.swift (text-layers fix round, #2175, #2177, #2180,
// #2181): the decisions behind the inspector's TEXT section. Which refusals
// it owns (its string, size and color controls), so the layer inspector's
// catch-all caption leaves them alone and each shows once, under the control
// it names; the field's draft, kept with the layer it was typed for, so it
// shows and commits only while that layer is selected; and the size bar's
// drag range, narrower than `fontSizeRange` so the usual sizes sit clear of
// the bar's label (typing still takes the whole range); and the field's key
// (#4310), which changes on a new selection and on an Undo or Redo of the
// words, so the field drops its draft and shows the stored words. Linux-safe.

/// The TEXT field's words while typing, and the layer they were typed for.
public struct HaloTextDraft: Sendable, Hashable {
    public let layerID: String
    public var words: String

    public init(layerID: String, words: String) {
        self.layerID = layerID
        self.words = words
    }

    /// Whether the draft belongs to `project`'s selected layer.
    public func applies(to project: HaloProject) -> Bool {
        project.selectedLayerID == layerID
    }

    /// What a commit sends on `project`: `.setText` while the draft's layer
    /// is still selected; nil otherwise, so typing never lands on another layer.
    public func commit(on project: HaloProject) -> HaloCommand? {
        applies(to: project) ? .setText(words) : nil
    }
}

/// What the TEXT field shows when no draft is open: the selected layer and
/// its stored words (nil without a text layer). The inspector rebuilds the
/// field and ends editing whenever it changes, so an Undo or Redo reaches a
/// focused field (#4310).
public struct HaloTextFieldKey: Sendable, Hashable {
    public let layerID: String?
    public let words: String?

    public init(layerID: String?, words: String?) {
        self.layerID = layerID
        self.words = words
    }
}

extension HaloTextContent {
    /// The size bar's drag range: 72 and 96 px sit past its label; larger
    /// sizes, up to `fontSizeRange`'s top, are typed.
    public static let sizeBarRange: ClosedRange<Double> = 1...200

    /// Where `size` sits on the size bar: clamped into `sizeBarRange`.
    public static func sizeBarPosition(_ size: Double) -> Double {
        guard !size.isNaN else { return sizeBarRange.lowerBound }
        return min(max(size, sizeBarRange.lowerBound), sizeBarRange.upperBound)
    }
}

extension HaloProject {
    /// The TEXT section's controls: the field, the size bar, the color row.
    public static let textControls = [textStringControl, textSizeControl, layerColorControl]

    /// Whether `refusal` names one of the TEXT section's controls.
    public static func textOwns(_ refusal: HaloRefusal) -> Bool {
        textControls.contains(refusal.control)
    }

    /// The refusal to show under the TEXT control `control`, if it names it.
    public func textRefusal(at control: String) -> HaloRefusal? {
        guard let refusal, refusal.control == control, Self.textControls.contains(control) else { return nil }
        return refusal
    }

    /// The words the TEXT field shows: `draft`'s while it belongs to the
    /// selected layer, else the stored words; nil without a text layer.
    public func textFieldWords(draft: HaloTextDraft?) -> String? {
        guard let text = selectedText else { return nil }
        if let draft, draft.applies(to: self) { return draft.words }
        return text.string
    }

    /// The TEXT field's key: the selected layer and its stored words.
    public var textFieldKey: HaloTextFieldKey {
        HaloTextFieldKey(layerID: selectedLayerID, words: selectedText?.string)
    }
}
