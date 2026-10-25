// FlarePlaceSnapshots.swift (svg-place PF-4; svg-place.md, Screens and states): Flare's window after a place, run
// as the menu and the drop run it (`FlareWorkspace.place(_:)`). `placed` (two-groups.svg centred; waits on PF-5)
// writes flare-place-svg-*.png; `report` (a blur the import skips) writes flare-place-report-*.png. macOS only.
import Foundation
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlarePlaceSnapshots {
    /// The journey kit's drawing: a red group and a blue group, 240×80.
    static let twoGroups = Data(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"240\" height=\"80\">"
        + "<g id=\"red\"><rect width=\"100\" height=\"80\" fill=\"#E53935\"/></g>"
        + "<g id=\"blue\"><rect x=\"140\" width=\"100\" height=\"80\" fill=\"#1E88E5\"/></g></svg>").utf8)

    /// A shape with a blur filter the import can't keep.
    static let blurred = Data(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"><defs>"
        + "<filter id=\"soft\"><feGaussianBlur stdDeviation=\"3\"/></filter></defs>"
        + "<rect width=\"100\" height=\"100\" fill=\"#1E88E5\" filter=\"url(#soft)\"/></svg>").utf8)

    /// A new animation on `.built`, as the journey's first step makes it.
    private func animation() -> FlareWorkspace {
        var model = FlareWorkspace(services: .built)
        model.newDocument()
        return model
    }

    @Test(.disabled("waits on PF-5")) func placed() throws {
        var model = animation()
        model.place([(name: "two-groups.svg", data: Self.twoGroups)])
        #expect(model.placeStatus == "Placed two-groups.svg: 2 layers.")
        let names = model.selectedScene?.layers.map(\.name) ?? []
        #expect(names.contains("red") && names.contains("blue"), "the place made \(names), not red and blue")
        try shoot("svg", model)
    }

    @Test func report() throws {
        var model = animation()
        model.place([(name: "soft.svg", data: Self.blurred)])
        #expect(model.placeStatus?.isEmpty == false, "the place left nothing in the status line")
        try shoot("report", model)
    }

    private func shoot(_ state: String, _ model: FlareWorkspace) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                FlareWindow(model: model)
                    .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "flare-place-\(state)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
