// LibraryLiveCropTests.swift: crop CR-3, the live crop geometry's checks
// (slice CR-b), written first and enabled by CR-4, which builds `LiveCrop` over
// CoreRaster's `straightenCrop`. They reach the geometry only through
// `LibraryServices.live(...).crop` and the `CropGeometry` protocol, so CR-4
// keeps that seam: `.live` sets `crop: LiveCrop()` and, once built, no
// "crop" reason. The helpers here are shared with LibraryCropRenderTests and
// LibraryCropBudgetTests. Runs on Linux and macOS.
@testable import LibraryModel
import CoreRaster
import Testing

/// The live services over fakes for the platform adapters.
func cropLiveServices() -> LibraryServices {
    LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
}

/// The live crop geometry (`LiveCrop` once CR-4 lands).
func cropLiveGeometry() -> any CropGeometry { cropLiveServices().crop }

/// The shoot sorted by name on the live services with `IMG_0001` (6000 × 4000) in the loupe.
func cropLiveLoupe() -> LibraryCatalog {
    var catalog = LibraryCatalog(services: cropLiveServices())
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    catalog.open("/fixture/shoot/IMG_0001.jpg")
    return catalog
}

/// `PixelBuffer.straightenCrop` as a `PixelRect`.
func cropStraightened(_ photo: PixelSize, degrees: Double) throws -> PixelRect {
    let sc = try PixelBuffer.straightenCrop(width: photo.width, height: photo.height, degrees: degrees)
    return PixelRect(x: sc.x, y: sc.y, width: sc.width, height: sc.height)
}

/// True when `frame` lies inside `outer`.
func cropLies(_ frame: PixelRect, inside outer: PixelRect) -> Bool {
    frame.x >= outer.x && frame.y >= outer.y
        && frame.x + frame.width <= outer.x + outer.width && frame.y + frame.height <= outer.y + outer.height
}

private let landscape = PixelSize(width: 6000, height: 4000)

@Suite
struct LibraryLiveCropTests {
    let crop = cropLiveGeometry()

    @Test func theLiveServicesHaveNoCropReason() {
        #expect(cropLiveServices().unavailable["crop"] == nil)
        #expect(cropLiveLoupe().cropHelp == nil)
    }

    @Test func aSquareOnALandscapeIsCentered() throws {
        let square = try crop.initial(aspect: .square, angle: 0, photo: landscape)
        #expect(square.aspect == .square && square.angle == 0)
        #expect(try crop.frame(square, photo: landscape) == PixelRect(x: 1000, y: 0, width: 4000, height: 4000))
    }

    @Test func originalAndFreeAtZeroAreTheWholePhoto() throws {
        for aspect in [CropAspect.original, .free] {
            let whole = try crop.initial(aspect: aspect, angle: 0, photo: landscape)
            #expect(whole.rect == .full)
            #expect(try crop.frame(whole, photo: landscape) == PixelRect(x: 0, y: 0, width: 6000, height: 4000))
        }
    }

    @Test func aSquareAtFiveDegreesIs3545AndLiesInsideTheStraightenCrop() throws {
        let square = try crop.initial(aspect: .square, angle: 5, photo: landscape)
        let frame = try crop.frame(square, photo: landscape)
        #expect((3544...3546).contains(frame.width))
        #expect(abs(frame.width - frame.height) <= 1)
        #expect(cropLies(frame, inside: try cropStraightened(landscape, degrees: 5)))
    }

    @Test func threeTwoOnAPortraitPhotoIsPortrait() throws {
        let portrait = PixelSize(width: 4000, height: 6000)
        let frame = try crop.frame(try crop.initial(aspect: .threeTwo, angle: 0, photo: portrait), photo: portrait)
        #expect(frame.height > frame.width)
        #expect(abs(Double(frame.height) / Double(frame.width) - 1.5) < 0.01)
        #expect(cropLies(frame, inside: try cropStraightened(portrait, degrees: 0)))
    }

    @Test(arguments: [CropHandle.topLeft, .topRight, .bottomRight, .bottomLeft])
    func aCornerDragOnASquareStaysSquare(_ handle: CropHandle) throws {
        for angle in [0.0, 5] {
            let square = try crop.initial(aspect: .square, angle: angle, photo: landscape)
            for (dx, dy) in [(300.0, 40.0), (-25.0, 260.0), (120.0, -120.0)] {
                let dragged = try crop.dragged(square, handle: handle, dx: dx, dy: dy, photo: landscape)
                let frame = try crop.frame(dragged, photo: landscape)
                #expect(dragged.aspect == .square)
                #expect(abs(frame.width - frame.height) <= 1, "\(handle) by \(dx), \(dy) at \(angle)°: \(frame)")
            }
        }
    }

    @Test func noDragMakesASideUnder16PxOrLeavesTheStraightenedPhoto() throws {
        let pulls: [(Double, Double)] = [(1e6, 1e6), (-1e6, -1e6), (1e6, -1e6), (-1e6, 1e6), (5990, 3990), (-5990, -3990)]
        for aspect in [CropAspect.free, .square, .sixteenNine] {
            for angle in [0.0, 5, -30] {
                let start = try crop.initial(aspect: aspect, angle: angle, photo: landscape)
                let outer = try cropStraightened(landscape, degrees: angle)
                for handle in CropHandle.allCases {
                    for (dx, dy) in pulls {
                        let r = try crop.dragged(start, handle: handle, dx: dx, dy: dy, photo: landscape).rect
                        let frame = try crop.frame(CropSettings(angle: angle, rect: r, aspect: aspect), photo: landscape)
                        let note: Comment = "\(aspect) \(angle)° \(handle) by \(dx), \(dy): \(r)"
                        #expect(r.x >= 0 && r.y >= 0 && r.x + r.width <= 1 + 1e-9 && r.y + r.height <= 1 + 1e-9, note)
                        #expect(frame.width >= 16 && frame.height >= 16, note)
                        #expect(cropLies(frame, inside: outer), note)
                    }
                }
            }
        }
    }

    @Test func insideMovesWithoutResizing() throws {
        let square = try crop.initial(aspect: .square, angle: 0, photo: landscape)
        let moved = try crop.dragged(square, handle: .inside, dx: 3, dy: 0, photo: landscape)
        #expect(try crop.frame(moved, photo: landscape) == PixelRect(x: 1003, y: 0, width: 4000, height: 4000))
    }

    @Test func straightenedKeepsTheRectAndClampsTheAngle() throws {
        let square = try crop.initial(aspect: .square, angle: 0, photo: landscape)
        let turned = try crop.straightened(square, angle: 5, photo: landscape)
        #expect(turned.rect == square.rect && turned.aspect == .square && turned.angle == 5)
        #expect(cropLies(try crop.frame(turned, photo: landscape), inside: try cropStraightened(landscape, degrees: 5)))
        #expect(try crop.straightened(square, angle: 60, photo: landscape).angle == 45)
        #expect(try crop.straightened(square, angle: -60, photo: landscape).angle == -45)
    }
}
