// CropAspectChoicesTests.swift (orientation-crop OC-5): the crop aspect picker's rules on Linux: chips and commands,
// the toggle's reasons, the custom ratio's sentences, and the frame a pick gives on a landscape image.
import Testing
import SuiteKernel

@Suite struct CropAspectChoicesTests {
    static let photo = Rect(minX: 0, minY: 0, maxX: 6000, maxY: 4000)

    @Test func everyChipNamesACommand() throws {
        let ids = Set(try CropShapeTarget.catalog().ids)
        #expect(CropAspectChoice.allCases.map(\.title) == ["Free", "Original", "1:1", "4:5", "3:2", "16:9", "Custom"])
        for chip in CropAspectChoice.allCases {
            #expect(ids.contains(chip.command), "\(chip) is bare: \(chip.command)")
            #expect(chip.identifier.hasPrefix("suite.crop.aspect-") && !chip.identifier.contains(":"))
        }
        #expect(ids.contains(CropAspectChoices.swapCommand) && CropAspectChoices.swapCommand == "crop.swap")
        #expect(Set(CropAspectChoice.allCases.map(\.identifier)).count == CropAspectChoice.allCases.count)
        #expect(CropAspectChoice.fourFive.aspect == .ratio(width: 4, height: 5) && CropAspectChoice.free.aspect == .free)
        #expect(CropAspectChoice.original.aspect == .original && CropAspectChoice.custom.aspect == nil)
        #expect([.ratio(width: 16, height: 9), .ratio(width: 7, height: 3), .free].map(CropAspectChoice.chip) == [.sixteenNine, .custom, .free])
    }

    @Test func toggleOffForFreeAndSquare() {
        #expect(CropAspectChoices.swapHelp(.free) != nil)
        #expect(CropAspectChoices.swapHelp(.ratio(width: 1, height: 1)) != nil)
        #expect(CropAspectChoices.swapHelp(.ratio(width: 5, height: 5)) != nil, "a typed 5:5 is a square too")
        #expect([.ratio(width: 4, height: 5), .ratio(width: 7, height: 3), .original].allSatisfy { CropAspectChoices.swapHelp($0) == nil })
    }

    @Test func customRefusesZeroWithASentence() {
        #expect(CropAspectChoices.custom(width: "7", height: "3") == .aspect(.ratio(width: 7, height: 3)))
        #expect(CropAspectChoices.custom(width: " 2 ", height: "3") == .aspect(.ratio(width: 2, height: 3)))
        for (w, h) in [("0", "3"), ("7", "0"), ("", "3"), ("7", ""), ("x", "3"), ("7", "2.5"), ("-1", "3"), ("1001", "3")] {
            guard case .problem(let sentence) = CropAspectChoices.custom(width: w, height: h) else {
                Issue.record("\(w):\(h) was taken"); continue
            }
            #expect(sentence.hasSuffix(".") && sentence.first?.isUppercase == true, "\(w):\(h) says \(sentence)")
        }
        #expect(CropAspectChoices.custom(width: "0", height: "3") != CropAspectChoices.custom(width: "", height: "3"),
                "0 and empty say the same thing")
        #expect(CropAspectChoices.orientation(of: .ratio(width: 7, height: 3), else: .portrait) == .landscape)
        #expect(CropAspectChoices.orientation(of: .ratio(width: 3, height: 7), else: .landscape) == .portrait)
        #expect(CropAspectChoices.orientation(of: .ratio(width: 2, height: 2), else: .portrait) == .portrait)
    }

    @Test func frameTurnsPortrait() {
        let wide = CropAspectChoices.frame(.ratio(width: 4, height: 5), .landscape, in: Self.photo)
        let tall = CropAspectChoices.frame(.ratio(width: 4, height: 5), .portrait, in: Self.photo)
        #expect(wide.width > wide.height && tall == Rect(minX: 1400, minY: 0, maxX: 4600, maxY: 4000))
        #expect(CropAspectChoices.frame(.free, .portrait, in: Self.photo) == Self.photo)
        #expect(CropAspectChoices.frame(.original, .landscape, in: Self.photo) == Self.photo)
        let original = CropAspectChoices.frame(.original, .portrait, in: Self.photo)
        #expect(original.height > original.width, "Original ignored the toggle")
        #expect(CropAspectChoices.line(CropPick(command: "crop.set-aspect", aspect: .ratio(width: 4, height: 5), orientation: .portrait))
            == "crop.set-aspect 4:5 portrait")
    }
}
