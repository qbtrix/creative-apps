// TinyDNG.swift: test support (SR-1). Stub; the writer follows.
import Foundation

enum TinyDNG {
    struct Spec: Sendable {
        var name: String
        var cfa: Bool
        static let bayer = Spec(name: "tiny-bayer.dng", cfa: true)
        static let linear = Spec(name: "tiny-linear.dng", cfa: false)
    }
    static let notRawName = "not-raw.nef"
    static let notRaw = Data()
    static let camera = "AfterGlow Test"
    static let marker: [UInt8] = [255, 0, 255]
    static let highlights: [Double] = [0.70, 0.90]
    static let patches: [(x: Int, y: Int)] = [(8, 8), (40, 8)]

    static func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures").appendingPathComponent("raw").appendingPathComponent(name)
    }

    static func write(_ spec: Spec) -> Data { Data() }
}
