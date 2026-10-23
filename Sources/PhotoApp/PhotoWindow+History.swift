// PhotoWindow+History.swift: the history area of a Photo window (history-panel
// PH-2): its intents, its route and its hook on the window. `jump` moves the
// image to a step of the History tab (the Model's `jumpHistory(to:)`; a refusal
// is the window's problem alert), and `showTab` picks the inspector's tab,
// which Window > History sets to History. The tab is the window's presentation
// state (`inspectorTab`); PhotoHistoryArea hands it to the inspector through
// the environment. Undo and Redo stay flat intents.
import PhotoModel
import SwiftUI

/// The tabs of a Photo window's inspector.
enum PhotoInspectorTab: Hashable, Sendable {
    case adjust, history
}

/// What the history area can be asked to do.
enum HistoryIntent {
    /// Go to the state after `index` steps (0 is the opened or new image).
    case jump(Int)
    /// Show `tab` in the inspector.
    case showTab(PhotoInspectorTab)
}

extension PhotoWindow {
    func performHistory(_ intent: HistoryIntent) {
        switch intent {
        case .jump(let index):
            do {
                try model.jumpHistory(to: index)
            } catch {
                problem = PhotoProblem("The image can't go to step \(index).", Self.reason(error))
            }
        case .showTab(let tab):
            inspectorTab = tab
        }
    }
}

/// The history area's state over the window: the inspector's tab.
struct PhotoHistoryArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    let tab: PhotoInspectorTab

    func body(content: Content) -> some View {
        content.environment(\.photoInspectorTab, tab)
    }
}

extension EnvironmentValues {
    /// The tab a Photo window's inspector shows (Adjust unless the window says).
    var photoInspectorTab: PhotoInspectorTab {
        get { self[PhotoInspectorTabKey.self] }
        set { self[PhotoInspectorTabKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, so PhotoApp builds without the SwiftUI
/// macro plugin (Command Line Tools).
private struct PhotoInspectorTabKey: EnvironmentKey {
    static let defaultValue = PhotoInspectorTab.adjust
}
