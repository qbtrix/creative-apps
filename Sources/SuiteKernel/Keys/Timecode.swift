// Timecode.swift (frame-rates FR-1 stubs, FR-3 bodies): the one timecode rule, HH:MM:SS:FF at a whole rate
// and drop-frame HH:MM:SS;FF at 29.97 and 59.94 (the broadcast convention), counted in the rate's nominal frames.
// Every function is total and never traps.

/// Frame numbers to timecode labels and back, for a frame rate.
public enum Timecode {
    /// The labels drop-frame skips at the start of each minute but every tenth: 2 at 29.97, 4 at 59.94, 0 otherwise.
    static func dropped(_ rate: FrameRate) -> Int { rate.isDropFrame ? rate.nominal / 15 : 0 }

    /// The label of `frame` at `rate`: `HH:MM:SS:FF`, or `HH:MM:SS;FF` when the rate is drop-frame.
    /// A negative frame reads as frame 0; a rate at or below 0 reads every frame as `00:00:00:00`.
    public static func string(frame: Int, rate: FrameRate) -> String {
        let fps = rate.nominal, drop = dropped(rate)
        guard fps > 0 else { return "00:00:00:00" }
        var count = min(max(0, frame), 1 << 52)
        if drop > 0 {
            let perMinute = fps * 60 - drop, tenMinutes = fps * 600 - drop * 9
            let (tens, rest) = count.quotientAndRemainder(dividingBy: tenMinutes)
            count += drop * 9 * tens + drop * (max(0, rest - drop) / perMinute)
        }
        let seconds = count / fps
        return "\(pad(seconds / 3600)):\(pad(seconds / 60 % 60)):\(pad(seconds % 60))\(drop > 0 ? ";" : ":")\(pad(count % fps))"
    }

    /// The frame `text` labels at `rate`; nil for text that isn't timecode or a label drop-frame skips.
    /// The last separator may be `:` or `;`; hours take up to six digits, the other fields two.
    public static func frame(_ text: String, rate: FrameRate) -> Int? {
        let fps = rate.nominal, drop = dropped(rate)
        let fields = text.split(separator: ":", omittingEmptySubsequences: false).flatMap {
            $0.split(separator: ";", omittingEmptySubsequences: false)
        }
        guard fps > 0, fps <= 100_000, fields.count == 4, text.filter({ $0 == ";" }).count <= 1, !text.dropLast(3).contains(";") else { return nil }
        let widths = [1...6, 2...2, 2...2, 2...2]
        var values: [Int] = []
        for (field, width) in zip(fields, widths) {
            guard width.contains(field.count), field.allSatisfy(\.isASCII), let value = Int(field), value >= 0 else { return nil }
            values.append(value)
        }
        let (hours, minutes, seconds, frames) = (values[0], values[1], values[2], values[3])
        guard minutes < 60, seconds < 60, frames < fps else { return nil }
        let totalMinutes = hours * 60 + minutes
        if drop > 0, seconds == 0, frames < drop, minutes % 10 != 0 { return nil }
        return ((totalMinutes * 60 + seconds) * fps + frames) - drop * (totalMinutes - totalMinutes / 10)
    }

    /// `value` as at least two digits.
    static func pad(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
}
