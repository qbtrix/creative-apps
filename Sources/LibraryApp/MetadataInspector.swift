// MetadataInspector.swift: the inspector for the selected photos, in the
// suite's inspector pattern (docs/design.md, Pro density): an InspectorHeader
// with the selection's name, then Metadata: rating stars, flag and color
// label dots. A field the photos differ in shows "Mixed". Values in, closures
// out; LibraryCatalog applies each edit to every selected photo. Each control
// carries its MetadataInspectorID. Each star and dot gets a 20 pt square hit
// frame (SuiteSize.iconButtonHit, docs/design.md's floor), edge to edge, and
// SuiteMarkStyle's hover and press fill behind it.
// "Mixed" stays one unbroken line: beside the marks when the row fits it,
// else above them (ViewThatFits), never squeezed mid-word (#1719). No Label
// draws circle.slash, since xmark is the grid's Rejected badge (#1721).
import LibraryModel
import SuiteUI
import SwiftUI

struct MetadataInspector: View {
    let metadata: PhotoMetadata
    var onStar: @MainActor (Int) -> Void = { _ in }
    var onFlag: @MainActor (PhotoFlag) -> Void = { _ in }
    var onLabel: @MainActor (PhotoLabel?) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader(metadata.title)
            InspectorSection("Metadata") {
                InspectorRow("Rating") { stars }
                InspectorPickerRow("Flag", options: flagOptions, selection: metadata.flag.shared) {
                    if let flag = $0 { onFlag(flag) }
                }
                .accessibilityIdentifier(MetadataInspectorID.flag)
                InspectorRow("Label") { labelDots }
            }
        }
    }

    /// Five stars; clicking the current rating's star clears it (the Model decides).
    private var stars: some View {
        mixedRow(metadata.rating == .mixed, id: Self.mixedID("rating")) {
            ForEach(1...5, id: \.self) { star in
                let title = star == 1 ? "1 Star" : "\(star) Stars"
                Button { onStar(star) } label: {
                    Image(systemName: star <= (metadata.rating.shared ?? 0) ? "star.fill" : "star")
                        .modifier(MarkHit())
                }
                .buttonStyle(SuiteMarkStyle())
                .help("Rate \(title); click the current rating to clear it")
                .accessibilityLabel(title)
                .accessibilityIdentifier(MetadataInspectorID.star(star))
            }
        }
    }

    /// No label, then a dot per color; the current one carries a check.
    private var labelDots: some View {
        mixedRow(metadata.label == .mixed, id: Self.mixedID("label")) {
            ForEach(Self.labelChoices, id: \.self) { label in
                let isOn = metadata.label == .value(label)
                Button { onLabel(label) } label: {
                    Group {
                        if let label {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle.fill").foregroundStyle(label.color)
                        } else {
                            Image(systemName: Self.noLabelSymbol)
                                .symbolVariant(isOn ? .fill : .none)
                                .foregroundStyle(SuiteColor.textSecondary)
                        }
                    }
                    .modifier(MarkHit())
                }
                .buttonStyle(SuiteMarkStyle())
                .help(label.map { "Label \($0.rawValue)" } ?? "No Label")
                .accessibilityLabel(label?.rawValue ?? "No Label")
                .accessibilityIdentifier(MetadataInspectorID.label(label))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private static let labelChoices: [PhotoLabel?] = [nil] + PhotoLabel.allCases.map { $0 }

    /// The No Label mark: a slashed circle, so it never reads as the Rejected xmark.
    static let noLabelSymbol = "circle.slash"

    /// The accessibility identifier of a row's "Mixed" text ("rating" or "label").
    static func mixedID(_ row: String) -> String { "library.metadata.mixed.\(row)" }

    /// The marks in a row; while the photos differ, "Mixed" on one line before
    /// them when it fits (the first mark's hit frame pads it), else above them.
    private func mixedRow<Marks: View>(
        _ isMixed: Bool, id: String, @ViewBuilder marks: () -> Marks
    ) -> some View {
        let row = HStack(spacing: 0) { marks() }
        return Group {
            if isMixed {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) { mixed(id: id); row }
                    VStack(alignment: .trailing, spacing: 0) { mixed(id: id); row }
                }
            } else {
                row
            }
        }
    }

    private func mixed(id: String) -> some View {
        Text(PhotoMetadata.mixedText).font(SuiteFont.inspectorValue).foregroundStyle(SuiteColor.textSecondary)
            .lineLimit(1)
            .fixedSize()
            .accessibilityIdentifier(id)
    }

    /// The flags, plus a Mixed entry only while the photos differ, so the menu shows it.
    private var flagOptions: [InspectorOption<PhotoFlag?>] {
        PhotoFlag.allCases.map { InspectorOption<PhotoFlag?>(id: $0, title: $0.rawValue) }
            + (metadata.flag == .mixed ? [InspectorOption(id: nil, title: PhotoMetadata.mixedText)] : [])
    }
}

/// A star's or dot's hit: a square at the icon-button floor, all of it clickable.
private struct MarkHit: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: SuiteSize.iconButtonHit, height: SuiteSize.iconButtonHit)
            .contentShape(.rect)
    }
}

extension PhotoLabel {
    /// The system color the label names; the name itself is its accessibility label.
    var color: Color {
        switch self {
        case .red: .red
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        }
    }
}
