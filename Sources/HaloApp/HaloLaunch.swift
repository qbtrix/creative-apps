// HaloLaunch.swift: the launch arguments the UI journeys start Halo with,
// read once from the process. `-HaloFixture <name>` opens a HaloFixtures
// project on fake services, `-HaloSample <name>` the same project on live
// services; `-HaloOpenFile <path>`, `-HaloSaveTo <file path>` and
// `-HaloRenderTo <folder>` are kept for the file and render areas to read, so
// a journey skips the panels; `-HaloWindowSize <w>x<h>` is the window's
// opening size (HaloApp); `-HaloControlsProbe` publishes the `halo.controls`
// JSON (HaloControls.swift); `-HaloPerfProbe` is kept for the frame probe
// (#330). Text layers always draw through HaloTextRasterizer. A switch over
// strings with no logic beyond HaloFixtures.project(_:): it is app-side, so
// Linux can't run it; HaloProjectLaunchTests covers the Model half.
import HaloModel
import SwiftUI

struct HaloLaunch: Sendable {
    var fixture: String?
    var sample: String?
    var openFile: String?
    var saveTo: String?
    var renderTo: String?
    /// `-HaloWindowSize`'s `<w>x<h>`, nil when absent or unreadable.
    var windowSize: CGSize?
    var controlsProbe = false
    var perfProbe = false

    /// This process's launch arguments.
    static let current = HaloLaunch(arguments: ProcessInfo.processInfo.arguments)

    /// The project every new window opens with, built once.
    static let project = current.project()

    init(arguments: [String]) {
        var rest = arguments.dropFirst()
        while let argument = rest.popFirst() {
            switch argument {
            case "-HaloFixture": fixture = rest.popFirst()
            case "-HaloSample": sample = rest.popFirst()
            case "-HaloOpenFile": openFile = rest.popFirst()
            case "-HaloSaveTo": saveTo = rest.popFirst()
            case "-HaloRenderTo": renderTo = rest.popFirst()
            case "-HaloWindowSize": windowSize = rest.popFirst().flatMap(Self.size)
            case "-HaloControlsProbe": controlsProbe = true
            case "-HaloPerfProbe": perfProbe = true
            default: break
            }
        }
    }

    /// The fixture (fake services) or sample (live services) project, else
    /// an empty live one; text through HaloTextRasterizer in every case.
    func project() -> HaloProject {
        var services = fixture == nil ? HaloServices.live : HaloServices.fake
        services.text = HaloTextRasterizer()
        guard let name = fixture ?? sample, let document = HaloFixtures.project(name) else {
            return HaloProject(services: services)
        }
        return HaloProject(services: services, document: document)
    }

    /// "1280x800" as a size; nil unless both sides are positive numbers.
    private static func size(_ text: String) -> CGSize? {
        let sides = text.split(separator: "x").compactMap { Double($0) }
        guard sides.count == 2, let width = sides.first, let height = sides.last, width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }
}
