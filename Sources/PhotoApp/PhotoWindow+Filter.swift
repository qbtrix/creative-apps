// PhotoWindow+Filter.swift (adjust-everywhere AJ-9): the filter area of a
// Photo window: its intents and their route. A Filter or Image > Adjustments
// item with a sheet opens SuiteUI's FilterSheet on the window's
// `filterDraft`; Invert runs at once. While the sheet is open its Preview
// shows the choice on a copy of the picture at most 1024 px on a side
// (`PhotoWorkspace.adjustPreview`, made off the main actor), so the document
// never changes until OK, which runs the sheet's catalog command as one undo
// step. Looks apply, save and delete through the catalog's look commands on
// the workspace's store (the suite's PresetStore, PhotoWindow+File.swift).
// PhotoFilterArea is the sheet over the window.
import CoreGraphics
import PhotoModel
import SuiteImaging
import SuiteKernel
import SuiteUI
import SwiftUI

/// What the filter area can be asked to do.
enum FilterIntent {
    /// A Filter or Adjustments menu item: its sheet, or Invert at once.
    case open(FilterMenuItem)
    /// The open sheet's new choices.
    case draft(FilterSheetDraft)
    /// The sheet's OK: run its filter or kind.
    case ok(FilterSheetIntent)
    case cancel
    /// A look's id applied, a name saved as a look, a saved look's id deleted.
    case applyLook(String), saveLook(String), deleteLook(String)
}

extension FilterSheetIntent {
    /// The catalog command and params this choice runs as.
    var command: (id: String, params: [String: JSONValue]) {
        switch self {
        case .filter(let f): PhotoWorkspace.adjustCommand(f)
        case .kind(let k): PhotoWorkspace.adjustCommand(k)
        }
    }
}

extension PhotoWindow {
    func performFilter(_ intent: FilterIntent) {
        switch intent {
        case .open(let item):
            if let sheet = item.sheet {
                filterDraft = FilterSheetDraft(sheet)
            } else {
                run(item.command, [:], failing: "\(item.title) can't run.")
            }
        case .draft(let draft): filterDraft = draft
        case .ok(let choice):
            let title = filterDraft?.title ?? "The filter"
            filterDraft = nil
            run(choice.command.id, choice.command.params, failing: "\(title) can't run.")
        case .cancel: filterDraft = nil
        case .applyLook(let id): run("look.apply", ["id": .string(id)], failing: "The look can't be applied.")
        case .saveLook(let name): run("look.save", ["name": .string(name)], failing: "The look can't be saved.")
        case .deleteLook(let id): run("look.delete", ["id": .string(id)], failing: "The look can't be deleted.")
        }
    }
}

/// The filter sheet over the window while `draft` is set.
struct PhotoFilterArea: ViewModifier {
    let model: PhotoWorkspace
    let draft: FilterSheetDraft?
    let perform: PhotoPerform

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { draft != nil }, set: { if !$0 { perform(.filter(.cancel)) } })) {
            if let draft { PhotoFilterSheet(model: model, draft: draft, perform: perform) }
        }
    }
}

/// FilterSheet with the Preview picture above it. Values in, intents out; owns only the preview picture.
struct PhotoFilterSheet: View {
    let model: PhotoWorkspace
    let draft: FilterSheetDraft
    let perform: PhotoPerform
    @State private var preview: CGImage?

    var body: some View {
        VStack(spacing: 0) {
            if draft.preview, let preview {
                Image(decorative: preview, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: SuiteSize.inspectorWidth.max, height: SuiteSize.inspectorWidth.ideal)
                    .padding(.top, SuiteSpacing.l)
                    .accessibilityLabel("Preview")
                    .accessibilityIdentifier("photo.filter.preview")
            }
            FilterSheet(draft: draft, target: model, onDraft: { perform(.filter(.draft($0))) },
                        onOK: { perform(.filter(.ok($0))) }, onCancel: { perform(.filter(.cancel)) })
        }
        .task(id: draft) {
            guard draft.preview, let command = draft.result(.ok)?.command else {
                preview = nil
                return
            }
            // A slider drag's later values cancel this one before it starts the work.
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            let workspace = model
            let shown = await Task.detached(priority: .userInitiated) {
                workspace.adjustPreview(command.id, command.params)
            }.value
            guard !Task.isCancelled else { return }
            preview = shown.flatMap {
                CanvasRenderer.image(rgba8: $0.rgba8, width: $0.width, height: $0.height, alpha: .last)
            }
        }
    }
}
