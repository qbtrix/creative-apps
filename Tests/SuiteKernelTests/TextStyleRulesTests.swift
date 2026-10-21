// TextStyleRulesTests.swift (text-style TS-1 written, TS-5 turns on): `TextStyleRules` ranges and `setting`, clamped
// to the format's ranges (size 1...1600 pt, line height 0.5...4, tracking -100...500 thousandths of an em), NaN keeping
// the old value. Disabled by name until TS-5 builds the bodies.
import Testing
import SuiteKernel

@Suite struct TextStyleRulesTests {
    @Test(.disabled("waits on TS-5")) func rangesAreTheFormats() {
        #expect(TextStyleRules.range(.size) == 1...1600)
        #expect(TextStyleRules.range(.lineHeight) == 0.5...4)
        #expect(TextStyleRules.range(.tracking) == -100...500)
    }
    @Test(.disabled("waits on TS-5")) func outOfRangeValuesClamp() {
        let s = TextStyle.standard
        #expect(TextStyleRules.setting(s, .size, to: 5000).size == 1600)
        #expect(TextStyleRules.setting(s, .size, to: 0).size == 1)
        #expect(TextStyleRules.setting(s, .lineHeight, to: 10).paragraph.lineHeight == 4)
        #expect(TextStyleRules.setting(s, .lineHeight, to: 0.1).paragraph.lineHeight == 0.5)
        #expect(TextStyleRules.setting(s, .tracking, to: 900).paragraph.tracking == 500)
        #expect(TextStyleRules.setting(s, .tracking, to: -500).paragraph.tracking == -100)
        #expect(TextStyleRules.setting(s, .lineHeight, to: 1.5).paragraph.lineHeight == 1.5)
        #expect(TextStyleRules.setting(s, .size, to: 36).size == 36)
    }
    @Test(.disabled("waits on TS-5")) func nanKeepsTheOldValue() {
        let s = TextStyle.standard
        for field in TextStyleField.allCases {
            #expect(TextStyleRules.setting(s, field, to: .nan) == s, "\(field)")
            #expect(TextStyleRules.setting(s, field, to: .infinity) == TextStyleRules.setting(s, field, to: TextStyleRules.range(field).upperBound), "\(field)")
        }
    }
    @Test(.disabled("waits on TS-5")) func standardIsThePackets() {
        let s = TextStyle.standard
        #expect(s.family == "System" && s.weight == 400 && !s.italic && s.size == 24)
        #expect(s.paragraph.alignment == .leading && s.paragraph.lineHeight == 1.2 && s.paragraph.tracking == 0)
    }
}
