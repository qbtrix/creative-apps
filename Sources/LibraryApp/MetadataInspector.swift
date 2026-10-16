// MetadataInspector.swift: the inspector for the selected photos, in the
// suite's inspector pattern (docs/design.md, Pro density): an InspectorHeader
// with the selection's name, then Metadata: rating stars, flag and color
// label dots. A field the photos differ in shows "Mixed". Values in, closures
// out; LibraryCatalog applies each edit to every selected photo. Each control
// carries its MetadataInspectorID. Each star and dot gets a 20 pt square hit
// frame (SuiteSize.iconButtonHit, docs/design.md's floor), edge to edge.
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
        HStack(spacing: 0) {
            if metadata.rating == .mixed { mixed }
            ForEach(1...5, id: \.self) { star in
                let title = star == 1 ? "1 Star" : "\(star) Stars"
                Button { onStar(star) } label: {
                    Image(systemName: star <= (metadata.rating.shared ?? 0) ? "star.fill" : "star")
                        .modifier(MarkHit())
                }
                .buttonStyle(.plain)
                .help("Rate \(title); click the current rating to clear it")
                .accessibilityLabel(title)
                .accessibilityIdentifier(MetadataInspectorID.star(star))
            }
        }
    }

    /// No label, then a dot per color; the current one carries a check.
    private var labelDots: some View {
        HStack(spacing: 0) {
            if metadata.label == .mixed { mixed }
            ForEach(Self.labelChoices, id: \.self) { label in
                let isOn = metadata.label == .value(label)
                Button { onLabel(label) } label: {
                    Group {
                        if let label {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle.fill").foregroundStyle(label.color)
                        } else {
                            Image(systemName: isOn ? "xmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(SuiteColor.textSecondary)
                        }
                    }
                    .modifier(MarkHit())
                }
                .buttonStyle(.plain)
                .help(label.map { "Label \($0.rawValue)" } ?? "No Label")
                .accessibilityLabel(label?.rawValue ?? "No Label")
                .accessibilityIdentifier(MetadataInspectorID.label(label))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private static let labelChoices: [PhotoLabel?] = [nil] + PhotoLabel.allCases.map { $0 }

    private var mixed: some View {
        Text(PhotoMetadata.mixedText).font(SuiteFont.inspectorValue).foregroundStyle(SuiteColor.textSecondary)
            .padding(.trailing, SuiteSpacing.xs)
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
