// GalleryMenus.swift: the gallery's menu pages. `menu-command` shows
// MenuCommand in a pull-down the way the apps' command menus use it: an item
// with a symbol and a key equivalent, a plain one, and one disabled with its
// reason as help. Its Edit menu also holds CopyAsMenu (clipboard-interop
// CB-u1) over `GalleryClipDocument`, a fake document whose pasteboard is a
// list of typed data the coder reads: Copy Text puts text on it, which turns
// Paste as Image off with the coder's sentence, and Copy As > PNG turns it on.
// The page shows the pasteboard (`suite.gallery.menu-command.pasteboard`),
// Paste as Image's help (`...paste-help`) and a log (`suite.gallery.log`).
import Foundation
import SuiteKernel
import SuiteModel
import SwiftUI

enum GalleryMenus {
    @MainActor static let pages: GalleryPages = ["menu-command": { AnyView(GalleryMenuCommandPage()) }]
}

/// The page's fake document: a selection and what its fake pasteboard offers.
struct GalleryClipDocument: CopyAsTarget {
    /// The app the gallery runs in, whose coder answers for Paste as Image.
    static let app = SuiteApp.library
    static let noSelection = "Select something to copy."
    static let ownType = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".suite.gallery-layers")

    private(set) var offered: [TypedData]
    private(set) var selected: Bool
    private(set) var pasted = 0

    init(offered: [TypedData] = [], selected: Bool = true) {
        self.offered = offered
        self.selected = selected
    }

    var copyAsHelp: String? { selected ? nil : Self.noSelection }

    var pasteAsImageHelp: String? { SuitePasteboardCoding().pasteRefusal(for: offered, in: Self.app)?.message }

    func copyAs(_ format: CopyAsFormat) throws -> CopiedBytes {
        switch format {
        case .png: CopiedBytes(type: SuiteTypeID.png.rawValue, data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        case .svg: CopiedBytes(type: SuiteTypeID.svg.rawValue, data: Data(#"<svg xmlns="http://www.w3.org/2000/svg"/>"#.utf8))
        case .own: CopiedBytes(type: Self.ownType.rawValue, data: Data("gallery layers".utf8))
        }
    }

    mutating func pasteAsImage(name: String, data: Data) throws { pasted += 1 }

    /// Copy As: the fake pasteboard now holds just that format's bytes.
    mutating func copy(_ format: CopyAsFormat) {
        guard let bytes = try? copyAs(format) else { return }
        offered = [TypedData(type: SuiteTypeID(rawValue: bytes.type), data: bytes.data)]
    }

    /// Copy Text: the fake pasteboard now holds plain text.
    mutating func copyText(_ text: String) {
        offered = [TypedData(type: .plainText, data: Data(text.utf8))]
    }

    /// "Pasteboard: text", "Pasteboard: public.png" or "Pasteboard: empty".
    var pasteboardLine: String {
        guard let type = offered.first?.type else { return "Pasteboard: empty" }
        return "Pasteboard: \(type == .plainText ? "text" : type.rawValue)"
    }
}

/// Internal, not private, so RenderBudgetCopyAsMenuTests reads `bodyRuns`.
struct GalleryMenuCommandPage: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif
    @State private var doc = GalleryClipDocument()
    @State private var log: [String] = []

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        let copyAs = CopyAsMenu(on: doc, ownTitle: "Gallery Layers", copy: copy, pasteAsImage: paste)
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Menu("Edit") {
                MenuCommand("Duplicate", systemImage: "plus.square.on.square", shortcut: KeyboardShortcut("d"),
                            help: "Duplicate the selection.") {}
                MenuCommand("Select All", help: "Select every layer.") {}
                MenuCommand("Paste", systemImage: "doc.on.clipboard", help: "There is nothing to paste.", isEnabled: false) {}
                Divider()
                copyAs
            }
            .fixedSize()
            .help("Edit")
            .suiteControl(id: "suite.gallery.menu-command.menu", enabled: true, reason: nil)
            Button("Copy Text") {
                doc.copyText("hello")
                send("copy text")
            }
            .help("Put text on the gallery's pasteboard.")
            .suiteControl(id: "suite.gallery.menu-command.copy-text", enabled: true, reason: nil)
            line(doc.pasteboardLine, id: "suite.gallery.menu-command.pasteboard")
            line(copyAs.pasteItem?.command.help ?? "", id: "suite.gallery.menu-command.paste-help")
            line(log.last ?? "Nothing yet", value: log.joined(separator: "\n"), id: "suite.gallery.log")
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func line(_ text: String, value: String? = nil, id: String) -> some View {
        Text(text).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
            .accessibilityValue(value ?? text)
            .accessibilityIdentifier(id)
    }

    private func copy(_ format: CopyAsFormat) {
        doc.copy(format)
        send("edit.copy-as \(format.rawValue)")
    }

    private func paste() {
        guard let image = doc.offered.first else { return }
        try? doc.pasteAsImage(name: "pasted", data: image.data)
        send("edit.paste-as-image \(doc.pasted)")
    }

    private func send(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
