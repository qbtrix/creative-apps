// FlareMenuSpec.swift (command-state CS-12): the catalog spec each Flare menu item, context menu item and sheet
// confirm is built on. `FlareIntent.commandID` names the catalog command an intent is, and `menuSpec(for:)` is that
// command's `menuSpec`, over the reason the focused window gives. An intent only the window can do (zoom, the
// Export sheet, Close) gets a window spec, titled by the intent and on exactly while that reason is nil, as
// Design's window specs are. Either way the item still acts through its window.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension FlareIntent {
    /// The catalog command this intent runs, or nil when only the window can do it.
    public var commandID: String? {
        switch self {
        case .file(let intent): intent.commandID
        case .edit(let intent): intent.commandID
        case .tools(.choose(let tool)): FlareWorkspace.toolID(tool)
        case .timeline(let intent): intent.commandID
        default: nil
        }
    }
}

extension FlareIntent.File {
    var commandID: String? {
        switch self {
        case .new, .create: "file.new"
        case .open: "file.open"
        case .openSample: "file.open-sample"
        case .save: "file.save"
        case .saveAs: "file.save-as"
        case .clearRecent: "file.clear-recent"
        case .openRecent, .close: nil
        }
    }
}

extension FlareIntent.Edit {
    var commandID: String {
        switch self {
        case .undo: "edit.undo"
        case .redo: "edit.redo"
        case .cut: "edit.cut"
        case .copy: "edit.copy"
        case .paste: "edit.paste"
        case .duplicate: "edit.duplicate"
        case .delete: "edit.delete"
        case .selectAll: "edit.select-all"
        case .deselect: "edit.deselect"
        case .bringForward: "object.bring-forward"
        case .sendBackward: "object.send-backward"
        }
    }
}

extension FlareIntent.Timeline {
    var commandID: String? {
        switch self {
        case .togglePlay: "animate.play"
        case .setLoops: "animate.loop"
        case .step(let frames): frames < 0 ? "animate.previous-frame" : "animate.next-frame"
        case .goToStart: "animate.go-to-start"
        case .goToEnd: "animate.go-to-end"
        case .setLabel: "frame.label"
        case .removeKeys: "timeline.delete-keys"
        case .insertFrames: "timeline.insert-frames"
        case .removeFrames: "timeline.remove-frames"
        case .selectAllKeys: "timeline.select-all-keys"
        default: nil
        }
    }
}

extension FlareWorkspace {
    /// The spec `intent`'s control is built on, over the focused window's reason (nil: it can run): its catalog
    /// command's `menuSpec`, else a window spec with the intent's identifier and title.
    public static func menuSpec(for intent: FlareIntent) -> CommandSpec<String?> {
        if let id = intent.commandID, let spec = menuSpec(id) { return spec }
        let id = intent.identifier, title = intent.title
        return .typed(id, title: title, summary: title, kind: .view, params: JSONValue.self, example: .object([:]),
                      availability: { $0.map(Availability.unavailable) ?? .available }) {
            (_: inout String?, _: JSONValue) throws -> JSONValue in
            throw CatalogError.unavailable(id: id, why: "Run \(title) from its window.")
        }
    }
}
