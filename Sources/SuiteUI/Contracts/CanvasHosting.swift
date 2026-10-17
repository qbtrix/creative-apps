// CanvasHosting.swift: the canvas host's contract (CH-1). Content tiles, the
// input delegate, the hit map's shape and the rendering preference's protocol,
// with the fakes that prove them. The AppKit host is CH-3, the live store CH-7,
// the tile set CH-8 and the hit map CH-6. macOS only (CoreGraphics and SwiftUI).
import Combine
import CoreGraphics
import Foundation
import SwiftUI

/// A whole-pixel rect in document space. Named apart from PhotoModel's `PixelRect`, which apps import too.
public struct CanvasTileRect: Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// One tile of document pixels. `image` is premultiplied sRGB; nil means the tile has no pixels yet.
public struct CanvasTile: Equatable, Sendable {
    public let rect: CanvasTileRect
    public let image: CGImage?
    public init(rect: CanvasTileRect, image: CGImage?) {
        self.rect = rect; self.image = image
    }
}

/// What the host draws. Apps conform; the host never reads their models.
public protocol CanvasContentProviding: Sendable {
    var documentSize: CGSize { get }
    /// The tiles to draw. With `dirtyOnly`, only the tiles changed since the last call.
    func tiles(dirtyOnly: Bool) -> [CanvasTile]
}

/// Receives pointer and key input from the host, in document points.
@MainActor
public protocol CanvasInputDelegate: AnyObject {
    func drag(from: CGPoint, to: CGPoint, pressure: Double, modifiers: EventModifiers)
    func endDrag()
    func hover(_ point: CGPoint?)
    func key(_ press: KeyPress) -> KeyPress.Result
}

/// Which marks sit under a point. CH-6 fills it with rects and paths and a hit slop.
public struct CanvasHitMap: Equatable, Sendable {
    public init() {}
}

/// The suite's Settings > Rendering choice. Automatic falls back to CPU when Metal stops.
public enum RenderingChoice: String, CaseIterable, Codable, Sendable {
    case automatic, gpu, cpu
}

/// What the pane shows: the backend in use, and a note when it differs from the choice.
public struct RenderingStatus: Equatable, Sendable {
    public var active: String
    public var note: String?
    public init(active: String, note: String?) {
        self.active = active; self.note = note
    }
}

/// The preference every app process reads live. Main-actor isolated, so observers and writes share one actor.
@MainActor
public protocol RenderingPreferenceReading: Sendable {
    var choice: RenderingChoice { get }
    var status: RenderingStatus { get }
    func set(_ choice: RenderingChoice)
    func observe(_ onChange: @escaping @Sendable @MainActor (RenderingChoice) -> Void) -> AnyCancellable
}

/// Twenty tiles in a 4 x 5 grid over a 4096 x 2160 document, each 1024 x 432 pixels, with no pixels yet.
/// `dirtyOnly` returns the same twenty: the fake has no dirty tracking.
public struct FakeCanvasContent: CanvasContentProviding {
    public let documentSize = CGSize(width: 4096, height: 2160)

    public init() {}

    public func tiles(dirtyOnly: Bool) -> [CanvasTile] {
        (0..<5).flatMap { row in
            (0..<4).map { column in
                CanvasTile(rect: CanvasTileRect(x: column * 1024, y: row * 432, width: 1024, height: 432), image: nil)
            }
        }
    }
}

/// In memory. `loseDevice()` stands in for Metal stopping: under `.automatic` the status falls back to CPU with a note.
@MainActor
public final class FakeRenderingPreference: RenderingPreferenceReading {
    public private(set) var choice: RenderingChoice
    public private(set) var deviceLost = false
    private var observers: [UUID: @Sendable @MainActor (RenderingChoice) -> Void] = [:]

    public init(choice: RenderingChoice = .automatic) {
        self.choice = choice
    }

    public var status: RenderingStatus {
        let fallsBack = choice == .cpu || (deviceLost && choice == .automatic)
        let note = deviceLost && choice == .automatic ? "Drawing on CPU: Metal stopped" : nil
        return RenderingStatus(active: fallsBack ? "CPU" : "GPU", note: note)
    }

    public func set(_ choice: RenderingChoice) {
        self.choice = choice
        for observer in observers.values { observer(choice) }
    }

    public func observe(_ onChange: @escaping @Sendable @MainActor (RenderingChoice) -> Void) -> AnyCancellable {
        let id = UUID()
        observers[id] = onChange
        // AnyCancellable may run this off the main actor (on deinit), so it hops back rather than assume isolation.
        return AnyCancellable { @Sendable [weak self] in
            let owner = self
            Task { @MainActor in owner?.removeObserver(id) }
        }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    public func loseDevice() {
        deviceLost = true
    }
}
