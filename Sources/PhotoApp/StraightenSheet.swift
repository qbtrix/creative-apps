// StraightenSheet.swift: Image > Straighten… asks for an angle from -45 to 45
// degrees (a slider and a field, 0.1 steps) and Crop to Fit (on by default),
// and says the size the image will be. The choices are a StraightenDraft, the
// window root's presentation state, so the canvas previews them while the
// sheet is open: PhotoCanvas turns the picture it already has with
// `.rotationEffect` (on the GPU, so the slider drag never waits for CoreRaster)
// and draws StraightenMarks over it. Apply hands the draft to the window;
// Cancel drops it. Values in, closures out. The field is a text field whose
// every keystroke updates the draft, as in ImageSizeSheet: a number field
// can wait for Return to commit, and Return is Apply (the field submits it
// itself, since it takes Return first), so "type 3, press Return" turns by 3. Controls carry `photo.straighten.*` identifiers.
import PhotoModel
import SuiteUI
import SwiftUI

/// The Straighten sheet's choices while it is open.
struct StraightenDraft: Equatable {
    var degrees = 0.0
    var cropToFit = true
}

struct StraightenSheet: View {
    let draft: StraightenDraft
    /// What Apply would make; nil when the image can't turn that far.
    let frame: StraightenFrame?
    var onDraft: @MainActor (StraightenDraft) -> Void = { _ in }
    var onApply: @MainActor () -> Void = {}
    var onCancel: @MainActor () -> Void = {}
    /// The angle as typed, until the slider moves; nil shows the draft's angle.
    @State private var typed: String?

    var body: some View {
        let tooFar = "The image is too large to turn that far."
        SuiteSheet(
            "Straighten", note: frame.map { "New size \($0.size.width) × \($0.size.height) px" } ?? tooFar,
            cancelIdentifier: "photo.straighten.cancel",
            confirm: .init(
                "Apply", identifier: "photo.straighten.apply", help: frame == nil ? tooFar : "Apply",
                isEnabled: frame != nil, perform: onApply),
            onCancel: onCancel
        ) {
            Form {
                LabeledContent("Angle") {
                    HStack(spacing: SuiteSpacing.s) {
                        Slider(
                            value: Binding(get: { draft.degrees }, set: { slide($0) }),
                            in: PhotoWorkspace.straightenRange, step: 0.1
                        )
                        .accessibilityLabel("Angle")
                        .accessibilityIdentifier("photo.straighten.slider")
                        TextField(
                            "Angle",
                            text: Binding(get: { typed ?? NumericInput.format(draft.degrees, decimals: 1) }, set: { typeAngle($0) })
                        )
                        .labelsHidden()
                        .frame(width: SuiteSize.inspectorField)
                        // The field takes Return before the default button does.
                        .onSubmit { if frame != nil { onApply() } }
                        .accessibilityLabel("Angle")
                        .accessibilityIdentifier("photo.straighten.angle")
                        Text("°")
                    }
                }
                Toggle("Crop to Fit", isOn: Binding(get: { draft.cropToFit }, set: { setCropToFit($0) }))
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("photo.straighten.crop")
            }
        }
    }

    private func setCropToFit(_ on: Bool) {
        onDraft(StraightenDraft(degrees: draft.degrees, cropToFit: on))
    }

    private func slide(_ degrees: Double) {
        typed = nil
        setDegrees(degrees)
    }

    /// Text that isn't a number yet ("-") keeps the last angle.
    private func typeAngle(_ text: String) {
        typed = text
        setDegrees(NumericInput.parse(text, in: PhotoWorkspace.straightenRange, keeping: draft.degrees))
    }

    /// Clamps to the range and rounds to the 0.1 step.
    private func setDegrees(_ degrees: Double) {
        let clamped = NumericInput.clamp(degrees, to: PhotoWorkspace.straightenRange)
        onDraft(StraightenDraft(degrees: (clamped * 10).rounded() / 10, cropToFit: draft.cropToFit))
    }
}

// ponytail: an app-side grid until SuiteUI's CanvasMarks has one.
/// The preview's marks over the canvas: a grid to line a horizon up with, over
/// the part that stays, and with Crop to Fit everything else shaded like a
/// pending crop (CropShade).
struct StraightenMarks: View {
    let frame: StraightenFrame
    let cropToFit: Bool
    let zoom: Double

    /// Grid cells along each side; a multiple of 3, so CropShade's thirds fall on grid lines.
    private static let cells = 9

    var body: some View {
        let canvas = CGRect(x: 0, y: 0, width: frame.canvas.width, height: frame.canvas.height)
        let crop = CGRect(x: frame.cropOrigin.x, y: frame.cropOrigin.y, width: Double(frame.crop.width), height: Double(frame.crop.height))
        let area = cropToFit ? crop : canvas
        ZStack(alignment: .topLeading) {
            if cropToFit { CropShade(rect: crop, documentSize: canvas.size, zoom: zoom) }
            Path { path in
                for line in 1..<Self.cells {
                    let share = Double(line) / Double(Self.cells)
                    let x = (area.minX + area.width * share) * zoom, y = (area.minY + area.height * share) * zoom
                    path.move(to: CGPoint(x: x, y: area.minY * zoom))
                    path.addLine(to: CGPoint(x: x, y: area.maxY * zoom))
                    path.move(to: CGPoint(x: area.minX * zoom, y: y))
                    path.addLine(to: CGPoint(x: area.maxX * zoom, y: y))
                }
            }
            .stroke(SuiteColor.overlayPaper.opacity(0.4), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
