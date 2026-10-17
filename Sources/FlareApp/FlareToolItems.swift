// FlareToolItems.swift: the stage palette's items. FlareTool conforms to
// SuiteUI's PaletteTool: each tool's title, SF Symbol and one-key shortcut
// (V Select, A Direct Select, R Rectangle, E Ellipse, P Pen), with its
// Model's `unavailableHelp` as the reason a tool that can't act yet shows
// disabled.
import FlareModel
import SuiteUI

extension FlareTool: PaletteTool {
    public var title: String {
        switch self {
        case .select: "Select"
        case .directSelect: "Direct Select"
        case .pen: "Pen"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        }
    }

    public var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .directSelect: "cursorarrow.rays"
        case .pen: "pencil.tip"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        }
    }

    public var shortcut: Character? {
        switch self {
        case .select: "v"
        case .directSelect: "a"
        case .rectangle: "r"
        case .ellipse: "e"
        case .pen: "p"
        }
    }
}
