// PhotoWindow+Select.swift: the selection area of a Photo window (area-selection AR-11): Select > Invert and
// Reselect run their catalog command; Feather…, Expand… and Contract… ask for a radius in an alert whose OK runs
// the command with it (a refusal opens the window's problem alert); the area tools' options go to the workspace.
// Select All, Deselect, Delete and Fill stay flat intents.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// What the selection area can be asked to do.
enum SelectIntent {
    /// Runs area command `id` with no params (Invert, Reselect).
    case run(String)
    /// Opens the radius alert for area command `id` (Feather, Expand, Contract).
    case ask(String)
    /// The radius alert's text as typed.
    case type(String)
    /// The radius alert's OK: runs its command with the typed radius.
    case applyRadius
    /// Closes the radius alert.
    case cancelRadius
    /// The area tools' mode, feather and wand options.
    case options(PhotoAreaOptions)
}

/// Feather…, Expand… or Contract…'s alert: the command it runs and the radius typed so far.
struct AreaRadiusPrompt: Equatable {
    let command: String
    var text = "8"

    /// The alert's title: the command's catalog title.
    var title: String { PhotoWorkspace.catalog.spec(command)?.title ?? "Selection" }
    /// The typed radius; nil when it isn't a number.
    var radius: Double? { Double(text.trimmingCharacters(in: .whitespaces)) }
}

extension PhotoWindow {
    func performSelect(_ intent: SelectIntent) {
        switch intent {
        case .run(let id): run(id, [:], failing: "The selection can't be changed.")
        case .ask(let id): areaPrompt = model.canvas == nil ? nil : AreaRadiusPrompt(command: id)
        case .type(let text): areaPrompt?.text = text
        case .applyRadius:
            guard let prompt = areaPrompt else { return }
            areaPrompt = nil
            let failing = "\(prompt.title) needs a radius from 0 to 250 px."
            guard let radius = prompt.radius else { return problem = PhotoProblem(failing, "“\(prompt.text)” isn't a number.") }
            run(prompt.command, ["radius": .number(radius)], failing: failing)
        case .cancelRadius: areaPrompt = nil
        case .options(let options): model.setAreaOptions(options)
        }
    }
}

/// The selection area's radius alert over the window.
struct PhotoSelectArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    let prompt: AreaRadiusPrompt?

    func body(content: Content) -> some View {
        content.alert(
            prompt?.title ?? "", isPresented: Binding(get: { prompt != nil }, set: { if !$0 { perform(.select(.cancelRadius)) } })
        ) {
            TextField("Radius", text: Binding(get: { prompt?.text ?? "" }, set: { perform(.select(.type($0))) }))
                .accessibilityIdentifier("photo.select.radius")
            if let id = prompt?.command, let spec = PhotoWorkspace.catalog.spec(id) {
                MenuCommand(spec, on: model, title: "OK") { perform(.select(.applyRadius)) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a radius in pixels, from 0 to 250.")
        }
    }
}
