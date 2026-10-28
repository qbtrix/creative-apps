// FontPicker.swift: SuiteUI's one font picker (packet
// docs/blueprints/suiteui/features/font-picker.md, FP-3). It takes font
// families and the current pick in, and reports picks out through `onPick`; it
// never reads a Model or a service. A search field narrows the family list
// (FontPickerRules.filtered), each family drawn in its own regular face; the
// Face menu lists the family's faces (FontPickerRules.orderedFaces) and the
// Size row drags over FontPickerRules.sizeBarRange and types any size in
// TextRules.sizes, in whole points. Picking another family
// keeps the size and moves to its face nearest the current one
// (FontPickerRules.nearestFace). The query is the picker's own state, so a
// keystroke runs this body and no host's (swiftui-rules 1).
//
// The search is a plain TextField, not `.searchable`: on the Mac that modifier
// puts its field in the window's toolbar, and this picker sits in a page,
// sheet or inspector that doesn't own one (two pickers would share it).
import AppKit
import SuiteModel
import SwiftUI

public struct FontPicker: View, BodyCounted {
    let families: [FontFamily]
    let pick: FontPick
    let onPick: (FontPick) -> Void
    @State private var query: String

    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    public init(families: [FontFamily], pick: FontPick, onPick: @escaping (FontPick) -> Void) {
        self.init(families: families, pick: pick, query: "", onPick: onPick)
    }

    /// `query` seeds the search field (the snapshots show a narrowed list).
    init(families: [FontFamily], pick: FontPick, query: String, onPick: @escaping (FontPick) -> Void) {
        self.families = families
        self.pick = pick
        self.onPick = onPick
        _query = State(initialValue: query)
    }

    public var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        let family = families.first { $0.name == pick.family }
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            TextField("Search", text: $query, prompt: Text("Search fonts"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .suiteControl(id: "suite.fontpicker.search", enabled: true, reason: nil)
            List(selection: familySelection) {
                ForEach(FontPickerRules.filtered(families, query: query)) { row in
                    FontPickerFamilyRow(name: row.name, selected: row.name == pick.family)
                        .equatable()
                        .tag(row.name)
                }
            }
            .frame(height: SuiteSize.studioRow * 10) // ten rows
            InspectorPickerRow(
                "Face", options: Self.faceOptions(family), selection: pick.face,
                onChange: { choose(Self.choosing(face: $0, from: pick)) }
            )
            .suiteControl(id: "suite.fontpicker.face", enabled: true, reason: nil)
            InspectorSliderRow(
                "Size", value: pick.size, in: TextRules.sizes, step: 1, unit: "pt",
                decimals: FontPickerRules.sizeDecimals, track: Self.sizeTrack,
                onChange: { choose(Self.choosing(size: $0, from: pick)) }
            )
            .suiteControl(id: "suite.fontpicker.size", enabled: true, reason: nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.fontpicker")
    }

    /// The list's selection: it reads the picked family; a click or arrow key picks one.
    private var familySelection: Binding<String?> {
        Binding<String?>(
            get: { pick.family },
            set: { name in
                guard let name, let next = families.first(where: { $0.name == name }) else { return }
                choose(Self.choosing(family: next, from: pick))
            })
    }

    /// Reports `next`; nil (nothing changed) reports nothing.
    func choose(_ next: FontPick?) {
        if let next { onPick(next) }
    }

    /// The row ids the list shows for `query`, in order: the family names.
    nonisolated static func rows(_ families: [FontFamily], query: String) -> [String] {
        FontPickerRules.filtered(families, query: query).map(\.id)
    }

    /// The Size bar's track: it drags over the common text sizes, not all of TextRules.sizes.
    nonisolated static let sizeTrack = ScrubTrack(
        positions: FontPickerRules.sizeBarRange, step: 1, position: { FontPickerRules.sizeBarPosition($0) },
        value: { $0 })

    /// The Face menu's options for `family`, in menu order; none without a family.
    nonisolated static func faceOptions(_ family: FontFamily?) -> [InspectorOption<FontFace>] {
        guard let family else { return [] }
        return FontPickerRules.orderedFaces(family).map { InspectorOption(id: $0, title: $0.name) }
    }

    /// The pick after choosing `family`: its face nearest the current one, the size kept; nil when unchanged.
    nonisolated static func choosing(family: FontFamily, from pick: FontPick) -> FontPick? {
        guard family.name != pick.family else { return nil }
        let face = FontPickerRules.nearestFace(in: family, to: pick.face) ?? pick.face
        return FontPick(family: family.name, face: face, size: pick.size)
    }

    /// The pick after choosing `face`; nil when unchanged.
    nonisolated static func choosing(face: FontFace, from pick: FontPick) -> FontPick? {
        face == pick.face ? nil : FontPick(family: pick.family, face: face, size: pick.size)
    }

    /// The pick after choosing `size`, rounded to a whole point inside TextRules.sizes; nil when unchanged or not a number.
    nonisolated static func choosing(size: Double, from pick: FontPick) -> FontPick? {
        guard size.isFinite else { return nil }
        let clamped = min(max(size.rounded(), TextRules.sizes.lowerBound), TextRules.sizes.upperBound)
        return clamped == pick.size ? nil : FontPick(family: pick.family, face: pick.face, size: clamped)
    }
}

/// One family row: its name in its own regular face at the body size, or the
/// shell's body font when the Mac doesn't have it. Plain values and no closure,
/// so `.equatable()` skips an unchanged row (swiftui-rules 2).
private struct FontPickerFamilyRow: View, Equatable {
    let name: String
    let selected: Bool

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name && lhs.selected == rhs.selected
    }

    var body: some View {
        Text(name)
            .font(Self.face(name) ?? SuiteFont.body)
            .lineLimit(1)
            .accessibilityLabel(name)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("suite.fontpicker.family.\(name)")
    }

    /// The family's regular face at the system font size; nil when the Mac doesn't have the family.
    // view-static: main-actor
    static func face(_ family: String) -> Font? {
        NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: NSFont.systemFontSize)
            .map { Font($0 as CTFont) }
    }
}
