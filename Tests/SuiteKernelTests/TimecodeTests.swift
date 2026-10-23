// TimecodeTests.swift (frame-rates FR-2 written, FR-3 turned on): HH:MM:SS:FF at whole rates, drop-frame
// HH:MM:SS;FF at 29.97 and 59.94, every label round-trips; and the two time.* specs each carry a schema.
import Foundation
import Testing
import SuiteKernel

@Suite struct TimecodeTests {
    static let ntsc = FrameRate(numerator: 30000, denominator: 1001)
    static let ntsc60 = FrameRate(numerator: 60000, denominator: 1001)

    /// 29.97 skips `;00` and `;01` each minute but every tenth (mutation `.tenthMinuteKeeps`).
    @Test func dropFrameAt2997() {
        #expect(Timecode.string(frame: 0, rate: Self.ntsc) == "00:00:00;00")
        #expect(Timecode.string(frame: 30, rate: Self.ntsc) == "00:00:01;00")
        #expect(Timecode.string(frame: 1799, rate: Self.ntsc) == "00:00:59;29")
        #expect(Timecode.string(frame: 1800, rate: Self.ntsc) == "00:01:00;02")
        #expect(Timecode.string(frame: 17982, rate: Self.ntsc) == "00:10:00;00")
        #expect(Timecode.string(frame: 107892, rate: Self.ntsc) == "01:00:00;00")
    }

    /// 59.94 skips four labels a minute, `;00` to `;03` (mutation `.dropCount5994`).
    @Test func dropFrameAt5994() {
        #expect(Timecode.string(frame: 3600, rate: Self.ntsc60) == "00:01:00;04")
        #expect(Timecode.string(frame: 35964, rate: Self.ntsc60) == "00:10:00;00")
        #expect(Timecode.frame("00:01:00;04", rate: Self.ntsc60) == 3600)
    }

    /// Whole rates count plainly with colons: 25 fps frame 90000 is one hour.
    @Test func wholeRatesUseColons() {
        #expect(Timecode.string(frame: 90000, rate: FrameRate(whole: 25)) == "01:00:00:00")
        #expect(Timecode.string(frame: 47, rate: FrameRate(whole: 24)) == "00:00:01:23")
        #expect(Timecode.string(frame: 25, rate: FrameRate(numerator: 24000, denominator: 1001)) == "00:00:01:01")
        #expect(Timecode.frame("01:00:00:00", rate: FrameRate(whole: 25)) == 90000)
    }

    /// A label drop-frame skips, a frame field past the rate or text that isn't timecode parses to nil.
    @Test func skippedAndMalformedLabelsAreNil() {
        #expect(Timecode.frame("00:01:00;00", rate: Self.ntsc) == nil && Timecode.frame("00:01:00;01", rate: Self.ntsc) == nil)
        #expect(Timecode.frame("00:10:00;00", rate: Self.ntsc) == 17982)
        #expect(Timecode.frame("00:00:00:30", rate: FrameRate(whole: 30)) == nil && Timecode.frame("one", rate: Self.ntsc) == nil)
    }

    /// Every frame of the first hour at 29.97 parses back to itself, and a sample at every common rate.
    @Test func everyLabelRoundTrips() {
        for frame in 0...107892 where Timecode.frame(Timecode.string(frame: frame, rate: Self.ntsc), rate: Self.ntsc) != frame {
            Issue.record("29.97 frame \(frame) does not round trip"); return
        }
        for rate in FrameRate.common {
            for frame in stride(from: 0, through: 400_000, by: 997) {
                #expect(Timecode.frame(Timecode.string(frame: frame, rate: rate), rate: rate) == frame)
            }
        }
    }

    /// One fixture entry: a rate and its frame-to-label pairs.
    struct GoldenRate: Decodable { var num, den: Int; var pairs: [[Golden]] }
    enum Golden: Decodable {
        case frame(Int), label(String)
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let frame = try? value.decode(Int.self) { self = .frame(frame) } else { self = .label(try value.decode(String.self)) }
        }
    }

    /// FR-4: 30 frame-to-label pairs per common rate (Fixtures/timecode-golden.json, read by path so no resource
    /// entry is needed); each label reads exactly and parses back, so a later edit can't drift a label.
    @Test func golden() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures").appendingPathComponent("timecode-golden.json")
        let rates = try JSONDecoder().decode([GoldenRate].self, from: Data(contentsOf: url))
        #expect(rates.map { FrameRate(numerator: $0.num, denominator: $0.den) } == FrameRate.common)
        for entry in rates {
            let rate = FrameRate(numerator: entry.num, denominator: entry.den)
            #expect(entry.pairs.count == 30)
            for pair in entry.pairs {
                guard pair.count == 2, case .frame(let frame) = pair[0], case .label(let label) = pair[1] else {
                    Issue.record("malformed pair at \(rate)"); continue
                }
                #expect(Timecode.string(frame: frame, rate: rate) == label, "\(rate) frame \(frame)")
                #expect(Timecode.frame(label, rate: rate) == frame, "\(rate) \(label)")
            }
        }
    }
}

/// FR-1: the two time.* commands exist as queries, each with a params schema its example passes.
@Suite struct TimeCommandsSpecTests {
    struct Probe: Sendable {}
    static let catalog = try? CommandCatalog(app: "test", TimeCommands.specs(Probe.self), history: { _ in History<Int>() })

    @Test func specsAreRatesAndTimecode() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == ["time.rates", "time.timecode"])
        for id in catalog.ids {
            let spec = try #require(catalog.spec(id))
            #expect(spec.kind == .query && !spec.undoable && spec.params.validate(spec.example).isEmpty)
            #expect(catalog.availability(id, on: Probe()) == .available)
        }
        let timecode = try #require(catalog.spec("time.timecode"))
        #expect(timecode.params != .none && !timecode.params.validate(.object(["frame": .number(1)])).isEmpty)
        #expect(timecode.params.validate(.object(["text": .string("00:00:01;00"), "rate": .object(["num": .number(30000), "den": .number(1001)])])).isEmpty)
    }

    /// FR-3: time.timecode labels a frame and reads a label back; time.rates lists the nine rates.
    @Test func timeCommandsRun() throws {
        let catalog = try #require(Self.catalog)
        var probe = Probe()
        let ntsc: JSONValue = .object(["num": .number(30000), "den": .number(1001)])
        let label = try catalog.run("time.timecode", params: .object(["frame": .number(1800), "rate": ntsc]), on: &probe)
        #expect(label.result == .object(["frame": .number(1800), "text": .string("00:01:00;02")]))
        let read = try catalog.run("time.timecode", params: .object(["text": .string("00:10:00;00"), "rate": ntsc]), on: &probe)
        #expect(read.result == .object(["frame": .number(17982), "text": .string("00:10:00;00")]))
        let skipped = try catalog.run("time.timecode", params: .object(["text": .string("00:01:00;00"), "rate": ntsc]), on: &probe)
        #expect(skipped.result == .object(["frame": .null, "text": .string("00:01:00;00")]))
        let rates = try catalog.run("time.rates", params: .object([:]), on: &probe)
        guard case .object(let body) = rates.result, case .array(let list)? = body["rates"] else { Issue.record("no rates"); return }
        #expect(list.count == 9)
        #expect(list.dropFirst(4).first == .object(["num": .number(30000), "den": .number(1001), "title": .string("29.97 fps"), "dropFrame": .bool(true)]))
    }
}
