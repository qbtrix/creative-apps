// DesignNewDocument+Kernel.swift (document-setup DS-10): Design's File > New on the kernel's DocumentSetup.
// The New Document sheet (SuiteUI NewDocumentSheet) offers `newDocumentPresets`, Design's frame sizes, and
// `file.new` takes the kernel's setup schema: `newFile(_:)` makes one page at the setup's pixel size (1 px
// is 1 pt) whose Desktop frame carries the background: white, a colour, or for transparent a solid of
// opacity 0, which the canvas draws clear. `shapeNewFile(_:)` reshapes the page a plain New File just made,
// in place inside its "New File" step, so the window can apply a setup after its unsaved guard ran.
// Linux-safe.
import SuiteKernel
import SuiteModel

extension DesignWorkspace {
    /// The sides a new file may have, in pixels.
    public static let newDocumentLimits = DocumentLimits()

    /// The setup the sheet opens on: the Desktop frame New File has always made.
    public static let newDocumentSetup = DocumentSetup(width: 1440, height: 1024)

    /// Design's frame presets, in the sheet's menu order.
    public static let newDocumentPresets: [NewDocumentPreset] = [
        preset("desktop", "Desktop", 1440, 1024),
        preset("laptop", "Laptop", 1280, 832),
        preset("tablet", "Tablet", 834, 1194),
        preset("phone", "Phone", 393, 852),
        preset("presentation", "Presentation", 1920, 1080),
        preset("square", "Square", 1080, 1080),
        preset("story", "Story", 1080, 1920),
    ]

    private static func preset(_ id: String, _ title: String, _ width: Int, _ height: Int) -> NewDocumentPreset {
        NewDocumentPreset(id: "design.\(id)", app: .design, title: title, detail: "\(width) × \(height)",
                          parameters: ["width": "\(width)", "height": "\(height)"])
    }

    /// File > New at `setup`: one page of its pixel size, the Desktop frame filled with its background,
    /// as one "New File" step. A setup past `newDocumentLimits` refuses with its first problem.
    public mutating func newFile(_ setup: DocumentSetup) throws {
        if let problem = setup.problems(Self.newDocumentLimits).first {
            throw CatalogError.failed(id: "file.new", message: problem.text)
        }
        newFile()
        shapeNewFile(setup)
    }

    /// Gives the page a plain New File just made `setup`'s size and background, inside that step, so Redo
    /// brings it back so. False, changing nothing, for any other file or a setup past the limits.
    @discardableResult public mutating func shapeNewFile(_ setup: DocumentSetup) -> Bool {
        guard isUntouchedNewFile, setup.problems(Self.newDocumentLimits).isEmpty,
              var page = pages.first, var frame = page.nodes.first
        else { return false }
        let (width, height) = setup.pixelSize
        (page.frameWidth, page.frameHeight) = (Double(width), Double(height))
        frame.frame = DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight)
        (frame.fill, frame.gradient) = Self.paint(setup.background)
        page.nodes = [frame]
        pages = [page]
        return true
    }

    /// The file is the one page and bare Desktop frame New File makes, unsaved and with no step after it.
    var isUntouchedNewFile: Bool {
        guard documentURL == nil, pages.count == 1, let page = pages.first, page.nodes.count == 1,
              let frame = page.nodes.first, frame.kind == .frame, frame.children.isEmpty
        else { return false }
        let size = Self.newDocumentSetup.pixelSize
        return page.frameWidth == Double(size.width) && page.frameHeight == Double(size.height)
            && frame.frame == DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight)
            && (history.kernel.undoName == nil || history.kernel.undoName == "New File")
    }

    /// The frame's colour and gradient for `background`: transparent is a solid of opacity 0 over white.
    static func paint(_ background: DocumentBackground) -> (DesignColor, Fill?) {
        switch background {
        case .white: return (.white, nil)
        case .transparent: return (.white, .solid(FillColor(r: 1, g: 1, b: 1, a: 0)))
        case .color(let hex):
            let digits = Array(hex.dropFirst())
            func byte(_ at: Int) -> UInt8 {
                guard at + 1 < digits.count else { return 255 }
                return UInt8(String(digits[at...at + 1]), radix: 16) ?? 255
            }
            let color = DesignColor(byte(0), byte(2), byte(4))
            guard digits.count == 8, byte(6) < 255 else { return (color, nil) }
            let opaque = color.kernelColor
            return (color, .solid(FillColor(r: opaque.r, g: opaque.g, b: opaque.b, a: Double(byte(6)) / 255)))
        }
    }
}

extension DesignHeadless {
    /// This document with `shapeNewFile(setup)` applied, for the window to adopt after its New File ran;
    /// nil when the file is not a plain New File (the unsaved guard was cancelled) or the setup is refused.
    public func shapingNewFile(_ setup: DocumentSetup) -> DesignHeadless? {
        var next = workspace
        guard next.shapeNewFile(setup) else { return nil }
        return DesignHeadless(next, name: name)
    }
}
