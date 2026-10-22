// NewDocumentSheet.swift (document-setup DS-5): the one sheet that starts a document and, in settings mode, edits
// it later: the app's presets (the clipboard image's size first, when there is one), width and height in a unit,
// resolution, the pixel size they make, orientation, background and, for timed apps, rate and duration. Settings
// mode drops the presets and adds the anchor grid that says where old content stays. Each field shows its
// SetupProblem beside it and Create stays off until there are none; every control's help names the `file.new` or
// `document.set-settings` parameter it sets. The rules are NewDocumentForm, plain and tested on its own; the sheet
// owns that form as presentation state, so typing redraws the sheet, not the window behind it.
import SuiteKernel
import SuiteModel
import SwiftUI

/// What the sheet is for: a new document from presets (and the clipboard image's size), or an open one's settings.
public enum NewDocumentMode: Sendable {
    case new(presets: [NewDocumentPreset], clipboard: (width: Int, height: Int)?)
    case settings

    /// The command the sheet's values become.
    public var command: String {
        if case .new = self { "file.new" } else { "document.set-settings" }
    }
}

/// The sheet's values and rules: the setup, the text in each field, the chosen preset and the anchor.
public struct NewDocumentForm: Sendable {
    /// The groups of controls the sheet shows.
    public enum Section: Hashable, Sendable { case presets, size, background, anchor, timing }
    /// White, transparent or a colour: the background picker's three choices.
    public enum BackgroundKind: String, CaseIterable, Sendable { case white, transparent, color }

    static let clipboardID = "clipboard"
    public private(set) var setup: DocumentSetup
    public private(set) var chosen: String?
    public private(set) var anchor = BoxAnchor.center
    public let limits: DocumentLimits
    private var texts: [SetupField: String] = [:]

    public init(_ setup: DocumentSetup, limits: DocumentLimits) {
        (self.setup, self.limits) = (setup, limits)
        refresh()
    }

    /// The text field `field` shows.
    public func text(_ field: SetupField) -> String { texts[field] ?? "" }
    public var problems: [SetupProblem] { setup.problems(limits) }
    public var canCreate: Bool { problems.isEmpty }
    /// The first problem on `field`; nil when it has none.
    public func problem(_ field: SetupField) -> String? { problems.first { $0.field == field }?.text }
    /// The pixel size the fields make: "1800 × 1200 px".
    public var readout: String { "\(setup.pixelSize.width) × \(setup.pixelSize.height) px" }
    public var backgroundKind: BackgroundKind {
        switch setup.background { case .white: .white; case .transparent: .transparent; case .color: .color }
    }

    /// Fills every field from `preset`: the fields it names, and px, 72 ppi and white where it names none.
    public mutating func pick(_ preset: NewDocumentPreset) {
        let p = preset.parameters
        setup.width = p["width"].flatMap(Double.init) ?? setup.width
        setup.height = p["height"].flatMap(Double.init) ?? setup.height
        setup.unit = p["unit"].flatMap(LengthUnit.init(rawValue:)) ?? .px
        setup.resolution = p["resolution"].flatMap(Double.init) ?? 72
        setup.background = p["background"].map(Self.background) ?? .white
        if limits.rates != nil {
            setup.frameRate = p["fps"].flatMap(Self.rate) ?? setup.frameRate
            setup.durationSeconds = p["duration"].flatMap(Double.init) ?? setup.durationSeconds
        }
        chosen = preset.id
        refresh()
    }

    /// The same pixels typed in `unit`.
    public mutating func setUnit(_ unit: LengthUnit) {
        setup = setup.converted(to: unit)
        chosen = nil
        refresh()
    }

    /// Keeps `text` in `field` and sets the value it spells; text that isn't a number sets 0, which a problem names.
    public mutating func type(_ text: String, into field: SetupField) {
        texts[field] = text
        let value = Double(text.trimmingCharacters(in: .whitespaces)) ?? 0
        switch field {
        case .width: setup.width = value
        case .height: setup.height = value
        case .resolution: setup.resolution = value
        case .duration: setup.durationSeconds = value
        case .background: setup.background = Self.background(text)
        case .frameRate: return
        }
        chosen = nil
    }

    public mutating func setBackground(_ kind: BackgroundKind) {
        switch kind {
        case .white: setup.background = .white
        case .transparent: setup.background = .transparent
        case .color: setup.background = .color(hex: texts[.background].flatMap { $0.isEmpty ? nil : $0 } ?? "#FFFFFF")
        }
        refresh()
    }

    public mutating func setRate(_ rate: FrameRate) { setup.frameRate = rate }
    public mutating func setAnchor(_ anchor: BoxAnchor) { self.anchor = anchor }

    /// Portrait to landscape and back.
    public mutating func swap() {
        setup = setup.swapped()
        refresh()
    }

    private mutating func refresh() {
        texts[.width] = Self.text(setup.width)
        texts[.height] = Self.text(setup.height)
        texts[.resolution] = Self.text(setup.resolution)
        texts[.duration] = setup.durationSeconds.map(Self.text) ?? ""
        if case .color(let hex) = setup.background { texts[.background] = hex }
    }

    /// A value as a field shows it: whole numbers bare, others to three places.
    static func text(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let rounded = (value * 1000).rounded() / 1000
        return rounded == rounded.rounded() && abs(rounded) < 1e15 ? String(Int(rounded)) : String(rounded)
    }

    static func background(_ text: String) -> DocumentBackground {
        switch text {
        case "white": .white
        case "transparent": .transparent
        default: DocumentBackground(parsing: text) ?? .color(hex: text)
        }
    }

    /// A preset's "fps": a whole rate, or the common rate it rounds (29.97).
    static func rate(_ text: String) -> FrameRate? {
        if let whole = Int(text) { return FrameRate(whole: whole) }
        guard let value = Double(text) else { return nil }
        return FrameRate.common.first { abs(Double($0.numerator) / Double($0.denominator) - value) < 0.01 }
    }

    /// The presets `mode` offers: the clipboard image's size first, when it has one.
    public static func choices(_ mode: NewDocumentMode) -> [NewDocumentPreset] {
        guard case .new(let presets, let clipboard) = mode else { return [] }
        guard let size = clipboard, size.width > 0, size.height > 0 else { return presets }
        let paste = NewDocumentPreset(id: clipboardID, app: presets.first?.app ?? .photo, title: "Clipboard",
                                      detail: "\(size.width) × \(size.height) px",
                                      parameters: ["width": "\(size.width)", "height": "\(size.height)"])
        return [paste] + presets
    }

    /// The sections `mode` shows: presets for a new document, the anchor grid for settings, timing for timed apps.
    public static func sections(_ mode: NewDocumentMode, limits: DocumentLimits) -> [Section] {
        var sections: [Section] = if case .new = mode { [.presets, .size, .background] } else { [.size, .anchor, .background] }
        if limits.rates != nil { sections.append(.timing) }
        return sections
    }

    /// The parameter a control sets: "file.new width".
    public static func parameter(_ name: String, _ mode: NewDocumentMode) -> String { "\(mode.command) \(name)" }
}

/// The New Document sheet, and Document Settings in `.settings` mode. Return creates, Escape cancels.
public struct NewDocumentSheet: View {
    private let mode: NewDocumentMode
    private let onDone: @MainActor (DocumentSetup, BoxAnchor) -> Void
    private let onCancel: @MainActor () -> Void
    @State private var form: NewDocumentForm

    public init(_ mode: NewDocumentMode, setup: DocumentSetup, limits: DocumentLimits,
                onDone: @escaping @MainActor (DocumentSetup, BoxAnchor) -> Void, onCancel: @escaping @MainActor () -> Void) {
        (self.mode, self.onDone, self.onCancel) = (mode, onDone, onCancel)
        _form = State(initialValue: NewDocumentForm(setup, limits: limits))
    }

    public var body: some View {
        let sections = NewDocumentForm.sections(mode, limits: form.limits)
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text(mode.command == "file.new" ? "New Document" : "Document Settings").font(SuiteFont.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: SuiteSpacing.m, verticalSpacing: SuiteSpacing.s) {
                if sections.contains(.presets) { presetRow }
                sizeRows
                if sections.contains(.anchor) { anchorRow }
                if sections.contains(.background) { backgroundRow }
                if sections.contains(.timing) { timingRows }
            }
            HStack(spacing: SuiteSpacing.s) {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier("suite.newdoc.cancel")
                Button(mode.command == "file.new" ? "Create" : "Apply") { onDone(form.setup, form.anchor) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(!form.canCreate).help(form.problems.first?.text ?? "Makes the document at this size")
                    .accessibilityIdentifier("suite.newdoc.create")
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentMinimum.width)
        .accessibilityIdentifier("suite.newdoc")
    }

    private var presetRow: some View {
        GridRow {
            Text("Preset")
            Picker("Preset", selection: Binding(get: { form.chosen ?? "" }, set: { id in
                if let preset = NewDocumentForm.choices(mode).first(where: { $0.id == id }) { form.pick(preset) }
            })) {
                Text("Custom").tag("")
                ForEach(NewDocumentForm.choices(mode), id: \.id) { Text($0.title).tag($0.id).help($0.detail) }
            }
            .labelsHidden().pickerStyle(.menu).help(NewDocumentForm.parameter("width and height, from a preset", mode))
            .accessibilityIdentifier("suite.newdoc.preset")
        }
    }

    @ViewBuilder private var sizeRows: some View {
        GridRow {
            Text("Size")
            HStack(spacing: SuiteSpacing.s) {
                field(.width, "Width")
                Button("Swap Width and Height", systemImage: "arrow.left.arrow.right") { form.swap() }
                    .labelStyle(.iconOnly).help("Swaps width and height").accessibilityIdentifier("suite.newdoc.swap")
                field(.height, "Height")
                Picker("Unit", selection: Binding(get: { form.setup.unit }, set: { form.setUnit($0) })) {
                    ForEach(LengthUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize().help(NewDocumentForm.parameter("unit", mode))
                .accessibilityIdentifier("suite.newdoc.unit")
            }
        }
        GridRow {
            Text("Resolution")
            HStack(spacing: SuiteSpacing.s) {
                field(.resolution, "Resolution")
                Text("ppi").foregroundStyle(SuiteColor.textSecondary)
                Spacer()
                Text(form.readout).font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
                    .accessibilityValue(form.readout).accessibilityIdentifier("suite.newdoc.pixels")
            }
        }
    }

    private var anchorRow: some View {
        GridRow {
            Text("Anchor")
            Grid(horizontalSpacing: SuiteSpacing.xxs, verticalSpacing: SuiteSpacing.xxs) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(BoxAnchor.allCases.dropFirst(row * 3).prefix(3), id: \.self) { anchor in
                            Button(anchor.rawValue, systemImage: form.anchor == anchor ? "circle.fill" : "circle") { form.setAnchor(anchor) }
                                .labelStyle(.iconOnly).help("Keeps old content at the \(anchor.rawValue): \(NewDocumentForm.parameter("anchor", mode))")
                                .accessibilityAddTraits(form.anchor == anchor ? .isSelected : [])
                                .accessibilityIdentifier("suite.newdoc.anchor-\(anchor.rawValue)")
                        }
                    }
                }
            }
        }
    }

    private var backgroundRow: some View {
        GridRow {
            Text("Background")
            HStack(spacing: SuiteSpacing.s) {
                Picker("Background", selection: Binding(get: { form.backgroundKind }, set: { form.setBackground($0) })) {
                    ForEach(NewDocumentForm.BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented).fixedSize().help(NewDocumentForm.parameter("background", mode))
                .accessibilityIdentifier("suite.newdoc.background")
                if form.backgroundKind == .color { field(.background, "#RRGGBB") }
            }
        }
    }

    @ViewBuilder private var timingRows: some View {
        GridRow {
            Text("Frame Rate")
            FrameRateMenu(rate: form.setup.frameRate ?? FrameRate(whole: 24)) { form.setRate($0) }
                .help(NewDocumentForm.parameter("frameRate", mode)).accessibilityIdentifier("suite.newdoc.rate")
        }
        GridRow {
            Text("Duration")
            HStack(spacing: SuiteSpacing.s) {
                field(.duration, "Duration")
                Text("s").foregroundStyle(SuiteColor.textSecondary)
            }
        }
    }

    /// A number field over `field`'s text, with its problem under it.
    private func field(_ field: SetupField, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xxs) {
            TextField(title, text: Binding(get: { form.text(field) }, set: { form.type($0, into: field) }))
                .textFieldStyle(.roundedBorder).labelsHidden().frame(width: SuiteSize.inspectorField)
                .help(NewDocumentForm.parameter(field.rawValue, mode))
                .accessibilityLabel(title).accessibilityIdentifier("suite.newdoc.\(field.rawValue)")
            if let problem = form.problem(field) {
                Label(problem, systemImage: "exclamationmark.circle").font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.stateError).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("suite.newdoc.\(field.rawValue).problem")
            }
        }
    }
}
