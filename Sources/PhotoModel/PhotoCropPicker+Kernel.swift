// PhotoCropPicker+Kernel.swift (orientation-crop OC-13): Photo's crop options on the shared
// CropAspectPicker. Photo keeps its lock as width : height with a portrait lock's sides swapped
// (2:3); the picker speaks the kernel's aspect, whose sides name the chip, and an orientation.
// A pick turns the kernel's aspect the way it stands and locks Photo's crop to it; the X toggle
// turns the lock as Swap does. Original's toggle locks to the image's own ratio turned the other
// way, so it is never dead. Linux-safe.
import SuiteKernel

extension PhotoWorkspace {
    /// The kernel aspect the picker shows: the chip whose sides Photo's lock has, either way round,
    /// else the lock's own sides (Custom).
    public var cropPickerAspect: SuiteKernel.CropAspect {
        switch cropAspect {
        case .free: return .free
        case .original: return .original
        case .ratio(let w, let h):
            let chip = CropAspectChoice.allCases.compactMap(\.aspect).first {
                guard case .ratio(let cw, let ch) = $0 else { return false }
                return (cw, ch) == (w, h) || (cw, ch) == (h, w)
            }
            return chip ?? .ratio(width: w, height: h)
        }
    }

    /// Which way Photo's lock stands: a ratio taller than wide, or Original on a taller image, is portrait.
    public var cropPickerOrientation: CropOrientation {
        switch cropAspect {
        case .ratio(let w, let h): return h > w ? .portrait : .landscape
        case .original: return (canvas.map { $0.height > $0.width } ?? false) ? .portrait : .landscape
        case .free: return .landscape
        }
    }

    /// Locks the crop to `pick`: its aspect turned as it stands, or, for the toggle, the lock turned.
    public mutating func pickCropAspect(_ pick: CropPick) {
        if pick.command == CropAspectChoices.swapCommand, cropPickerOrientation == pick.orientation { return }
        switch pick.aspect {
        case .free:
            setCropAspect(.free)
        case .original:
            guard let canvas, (canvas.height > canvas.width ? CropOrientation.portrait : .landscape) != pick.orientation,
                canvas.width != canvas.height
            else { return setCropAspect(.original) }
            let g = Self.divisor(canvas.width, canvas.height)
            if pick.command == CropAspectChoices.swapCommand {
                // Swap from the image's own ratio, so the pending crop turns about its centre.
                cropAspect = .ratio(canvas.width / g, canvas.height / g)
                swapCropAspect()
            } else {
                setCropAspect(.ratio(canvas.height / g, canvas.width / g))
            }
        case .ratio(let w, let h):
            let (long, short) = (max(w, h), min(w, h))
            let turned: CropAspect = long == short ? .ratio(w, h) : pick.orientation == .portrait ? .ratio(short, long) : .ratio(long, short)
            if pick.command == CropAspectChoices.swapCommand, case .ratio = cropAspect, turned != cropAspect, canvas != nil {
                swapCropAspect()
            } else {
                setCropAspect(turned)
            }
        }
    }

    /// The greatest common divisor of two sides, at least 1.
    private static func divisor(_ a: Int, _ b: Int) -> Int {
        var (x, y) = (abs(a), abs(b))
        while y != 0 { (x, y) = (y, x % y) }
        return max(x, 1)
    }
}
