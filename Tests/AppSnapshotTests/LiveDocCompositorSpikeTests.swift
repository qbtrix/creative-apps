// LiveDocCompositorSpikeTests.swift: the Live Doc compositor spike (branch spike/live-doc-compositor, never merged).
// One mixed fixture (`mixed`): N leaves in a keyed frame, by tens 6 rectangles, 2 texts, 1 gradient and 1 stroke,
// plus one placed 2048 x 1536 PNG, every node keyed on x, y and opacity over 120 frames. Route 1 (`painterPlayback`,
// `painterRaster`) plays it on today's SwiftUI painter through the real Design window, as
// RenderBudgetDesignAnimateTests.playback does. Route 2 (`layerPlayback`) puts it on SuiteUI's CanvasHostView as
// prerendered CALayers moved by sampled transforms: `twoLayers` (the raster and one vector group) and `perNode`
// (one layer per painted node). Each prints p50/p95/max, frames over 8.3 and 16.7 ms, window bodies and the
// 1-minute load. Nothing is gated. Run on a release build:
// `swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --no-parallel --filter LiveDocCompositorSpike`.
#if canImport(AppKit)
import AppKit
import ImageIO
@testable import DesignModel
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct LiveDocCompositorSpikeTests {
        // MARK: Fixture

        static let picture: PlacedAsset = {
            let (w, h) = (2048, 1536)
            let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            for i in 0..<64 {  // enough detail that the PNG is not trivially small
                ctx.setFillColor(CGColor(red: Double(i % 8) / 8, green: Double(i / 8) / 8, blue: 0.5, alpha: 1))
                ctx.fill(CGRect(x: (i % 8) * 256, y: (i / 8) * 192, width: 256, height: 192))
                ctx.setStrokeColor(CGColor(gray: Double(i) / 64, alpha: 1))
                ctx.strokeEllipse(in: CGRect(x: (i % 8) * 256 + 20, y: (i / 8) * 192 + 20, width: 200, height: 150))
            }
            let data = NSMutableData()
            let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
            CGImageDestinationFinalize(dest)
            return PlacedAsset(id: PlaceRules.assetID(of: data as Data), name: "photo.png", format: .png,
                               natural: Size(width: Double(w), height: Double(h)), data: data as Data)
        }()

        static func keyed(_ node: DesignNode, dx: Double, dy: Double) -> DesignNode {
            var node = node
            let (x, y) = (node.frame.x, node.frame.y)
            node.time = DesignNodeTime(tracks: [
                .x: [Keyframe(frame: 0, value: x), Keyframe(frame: 120, value: x + dx)],
                .y: [Keyframe(frame: 0, value: y), Keyframe(frame: 120, value: y + dy)],
                .opacity: [Keyframe(frame: 0, value: 1), Keyframe(frame: 120, value: 0.3)],
            ])
            return node
        }

        /// `count` mixed leaves plus one placed picture, in one keyed frame; ids node-1 (frame) ... node-(count+2) (picture).
        static func mixed(_ count: Int) -> DesignWorkspace {
            let blueToWhite = Fill.linear(
                stops: [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 1)), GradientStop(offset: 1, color: .white)],
                start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
            func cell(_ i: Int, _ w: Double, _ h: Double) -> DesignRect {
                DesignRect(x: 30 + Double(i % 25) * 54, y: 30 + Double(i / 25) * 48, width: w, height: h)
            }
            var leaves: [DesignNode] = (0..<count).map { i in
                switch i % 10 {
                case 6, 7: DesignNode(id: "", name: "Text", kind: .text, frame: cell(i, 48, 20), text: "Label")
                case 8: DesignNode(id: "", name: "Gradient", kind: .rectangle, frame: cell(i, 24, 16), gradient: blueToWhite)
                case 9: DesignNode(id: "", name: "Stroke", kind: .rectangle, frame: cell(i, 24, 16),
                                   stroke: i.isMultiple(of: 20) ? DesignStroke(width: 1) : DesignStroke(width: 1, dash: [4, 2]))
                default: DesignNode(id: "", name: "Rectangle", kind: .rectangle, frame: cell(i, 24, 16))
                }
            }
            var photo = DesignNode(id: "", name: "Photo", kind: .rectangle,
                                   frame: DesignRect(x: 880, y: 540, width: 480, height: 360), cornerRadius: 8)
            photo.placedAsset = picture
            leaves.append(photo)
            let cells = leaves.enumerated().map { i, leaf in keyed(DesignNode(id: "node-\(i + 2)", copying: leaf), dx: 24, dy: 20) }
            var frame = DesignNode(id: "node-1", name: "Frame 1", kind: .frame,
                                   frame: DesignRect(x: 10, y: 10, width: 1400, height: 1000), children: cells)
            frame.time = DesignNodeTime(tracks: [.x: [Keyframe(frame: 0, value: 10), Keyframe(frame: 120, value: 20)]])
            var workspace = DesignWorkspace()
            workspace.load([DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [frame])])
            return workspace
        }

        static func load() -> Double {
            var l = [0.0, 0, 0]
            getloadavg(&l, 3)
            return l[0]
        }

        static func stats(_ label: String, _ times: [Double], bodies: String, extra: String = "") {
            let s = times.sorted()
            print(String(format: "LDSPIKE %@: %d frames | p50 %.3f p95 %.3f max %.2f ms | over 8.3 ms %d | over 16.7 ms %d | window bodies %@ | load %.1f%@",
                         label, s.count, s[s.count / 2], s[Int(Double(s.count) * 0.95)], s.last ?? 0,
                         s.filter { $0 > 8.33 }.count, s.filter { $0 > 16.7 }.count, bodies, load(), extra))
        }

        static func ms(_ d: Duration) -> Double { Double(d / .microseconds(1)) / 1000 }

        // MARK: Route 1, the SwiftUI painter

        @Test(.timeLimit(.minutes(3)), arguments: [50, 500]) func painterPlayback(nodes: Int) async throws {
            let live = DesignLiveDrag()
            var links: [HaloFakeLink] = []
            let seed = Self.mixed(nodes)
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: live).environment(\.designRefreshLink) { receive in
                let link = HaloFakeLink(receive)
                links.append(link)
                return link
            })
            defer { w.close() }
            try await w.settle(800)
            #if DEBUG
            try await w.settle(untilStable: { DesignWindow.bodyRuns })
            let perform = try #require(DesignWindow.lastPerform, "the window never started")
            perform(.play)
            let link = try #require(links.last, "play never started the driver")
            let start = 5000.0
            link.fire(start)
            let before = DesignWindow.bodyRuns
            var whilePlaying = before
            var times: [Double] = []
            let clock = ContinuousClock()
            for i in 1...600 {
                whilePlaying = DesignWindow.bodyRuns
                let began = clock.now
                link.fire(start + Double(i) / 120)
                w.host.layoutSubtreeIfNeeded()
                w.window.displayIfNeeded()
                times.append(Self.ms(clock.now - began))
                guard live.playingFrame != nil else { break }
                if i % 30 == 0 { try await Task.sleep(for: .milliseconds(1)) }
            }
            // Steady state: the first refresh (play start) and the last (play end, the landing) are reported apart.
            let steady = Array(times.dropFirst().dropLast())
            Self.stats("route1 painter mixed(\(nodes)) \(seed.selectedPage.map { $0.painted.count } ?? 0) painted", steady,
                       bodies: "\(whilePlaying - before)",
                       extra: String(format: " | refresh 1 %.2f ms | last %.2f ms", times.first ?? 0, times.last ?? 0))
            perform(.stop)
            #endif
        }

        @Test(.timeLimit(.minutes(3)), arguments: [50, 500]) func painterRaster(nodes: Int) throws {
            let page = try #require(Self.mixed(nodes).selectedPage)
            let total = page.painted.count
            func raster(_ frame: Double) {
                let renderer = ImageRenderer(content: DesignArtwork(painted: page.sampled(at: frame).painted, zoom: 1)
                    .frame(width: page.frameWidth, height: page.frameHeight))
                renderer.scale = 2
                _ = renderer.cgImage
            }
            raster(0)  // warm-up: fonts and the picture's decode
            var times: [Double] = []
            for frame in stride(from: 0, through: 120, by: 4) {
                let clock = ContinuousClock(), began = clock.now
                raster(Double(frame))
                times.append(Self.ms(clock.now - began))
            }
            let s = times.sorted()
            Self.stats("route1 raster mixed(\(nodes)) \(total) painted at 2x", times, bodies: "n/a",
                       extra: String(format: " | per node p50 %.2f p95 %.2f us", s[s.count / 2] * 1000 / Double(total),
                                     s[Int(Double(s.count) * 0.95)] * 1000 / Double(total)))
        }

        // MARK: Route 2, CALayers on CanvasHostView

        struct Doc: CanvasContentProviding {
            let documentSize: CGSize
            func tiles(dirtyOnly: Bool) -> [CanvasTile] { [] }
        }

        /// The canvas host inside a SwiftUI window, so the window's own body runs can be counted.
        struct HostBox: View {
            nonisolated(unsafe) static var bodies = 0
            let host: CanvasHostView
            var body: some View {
                Self.bodies += 1
                return Representable(host: host)
            }
            struct Representable: NSViewRepresentable {
                let host: CanvasHostView
                func makeNSView(context: Context) -> CanvasHostView { host }
                func updateNSView(_ nsView: CanvasHostView, context: Context) {}
            }
        }

        static let scale = 2.0

        /// `items` drawn once at `scale` into one image `size` points, `origin` at its top-left.
        static func prerender(_ items: [DesignPainted], origin: CGPoint, size: CGSize) -> CGImage? {
            let renderer = ImageRenderer(content: DesignArtwork(painted: items, zoom: 1)
                .frame(width: size.width + origin.x, height: size.height + origin.y)
                .offset(x: -origin.x, y: -origin.y)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped())
            renderer.scale = scale
            return renderer.cgImage
        }

        enum Mode: String, CaseIterable { case twoLayers, perNode }

        @Test(.timeLimit(.minutes(5)), arguments: [50, 500], Mode.allCases)
        func layerPlayback(nodes: Int, mode: Mode) async throws {
            let page = try #require(Self.mixed(nodes).selectedPage)
            let rest = page.painted.map { DesignPainted(node: $0.node, backdrop: $0.backdrop, opacity: 1, stroke: $0.stroke) }
            let doc = CGSize(width: page.frameWidth * Self.scale, height: page.frameHeight * Self.scale)
            let host = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 1280, height: 820))
            host.isEmbedded = true
            host.show(Doc(documentSize: doc))
            HostBox.bodies = 0
            let w = RenderBudgetWindow(HostBox(host: host))
            defer { w.close() }
            try await w.settle(500)

            // Lift: prerender each layer's pixels once (timed apart, it is the lift's cost, not a frame's).
            let photoID = "node-\(nodes + 2)"
            struct Lift { let ids: [String]; let origin: CGPoint; let layer: CALayer }
            var lifts: [Lift] = []
            let liftClock = ContinuousClock(), liftBegan = liftClock.now
            func layer(_ image: CGImage?, size: CGSize) -> CALayer {
                let l = CALayer()
                l.anchorPoint = .zero
                l.position = .zero
                l.bounds = CGRect(origin: .zero, size: CGSize(width: size.width * Self.scale, height: size.height * Self.scale))
                l.contents = image
                return l
            }
            switch mode {
            case .twoLayers:
                // The vector group (frame + every leaf but the picture) and the picture, each one layer.
                let vectors = rest.filter { $0.id != photoID }, photo = rest.filter { $0.id == photoID }
                let pageSize = CGSize(width: page.frameWidth, height: page.frameHeight)
                lifts.append(Lift(ids: vectors.map(\.id), origin: .zero,
                                  layer: layer(Self.prerender(vectors, origin: .zero, size: pageSize), size: pageSize)))
                let p = try #require(photo.first).node.frame
                let o = CGPoint(x: p.x, y: p.y), s = CGSize(width: p.width, height: p.height)
                lifts.append(Lift(ids: [photoID], origin: o, layer: layer(Self.prerender(photo, origin: o, size: s), size: s)))
            case .perNode:
                for item in rest {
                    let f = item.node.frame
                    let o = CGPoint(x: f.x - 2, y: f.y - 2), s = CGSize(width: f.width + 4, height: f.height + 4)  // room for strokes
                    lifts.append(Lift(ids: [item.id], origin: o, layer: layer(Self.prerender([item], origin: o, size: s), size: s)))
                }
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for lift in lifts {
                lift.layer.name = "ld-spike"
                host.liftSpace.addSublayer(lift.layer)
            }
            CATransaction.commit()
            let liftMs = Self.ms(liftClock.now - liftBegan)
            try await w.settle(200)

            // Each refresh: sample the tree at the frame, set every layer's transform and opacity in one actions-off
            // transaction, flush, and force layout and display.
            let restByID = Dictionary(rest.map { ($0.id, $0.node.frame) }) { a, _ in a }
            let bodiesBefore = HostBox.bodies, layoutsBefore = w.host.layouts
            var times: [Double] = [], sampleTimes: [Double] = []
            let clock = ContinuousClock()
            for i in 0..<600 {
                let frame = Double(i % 120)
                let began = clock.now
                let sampled = page.sampled(at: frame).painted
                let byID = Dictionary(sampled.map { ($0.id, $0) }) { a, _ in a }
                let sampledAt = clock.now
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                for lift in lifts {
                    // The group moves by its first node's offset from rest (the frame's for the vector group).
                    guard let lead = lift.ids.first, let now = byID[lead], let was = restByID[lead] else { continue }
                    let (dx, dy) = (now.node.frame.x - was.x, now.node.frame.y - was.y)
                    let t = CGAffineTransform(translationX: (lift.origin.x + dx) * Self.scale, y: (lift.origin.y + dy) * Self.scale)
                    lift.layer.setAffineTransform(CanvasHostView.liveTransform(t, size: lift.layer.bounds.size, document: doc))
                    lift.layer.opacity = Float(lift.ids.count == 1 ? now.opacity : 1)
                }
                CATransaction.commit()
                CATransaction.flush()
                w.host.layoutSubtreeIfNeeded()
                w.window.displayIfNeeded()
                times.append(Self.ms(clock.now - began))
                sampleTimes.append(Self.ms(sampledAt - began))
                if i % 30 == 0 { try await Task.sleep(for: .milliseconds(1)) }
            }
            let bytes = lifts.reduce(0.0) { $0 + Double($1.layer.bounds.width * $1.layer.bounds.height * 4) }
            let ss = sampleTimes.sorted()
            Self.stats("route2 \(mode.rawValue) mixed(\(nodes)) \(lifts.count) layers", times,
                       bodies: "\(HostBox.bodies - bodiesBefore) (layouts \(w.host.layouts - layoutsBefore))",
                       extra: String(format: " | sample p50 %.3f ms | lift %.1f ms | layer pixels %.1f MB", ss[ss.count / 2], liftMs, bytes / 1e6))
            #expect(lifts.count == (mode == .twoLayers ? 2 : rest.count))
        }
    }
}
#endif
