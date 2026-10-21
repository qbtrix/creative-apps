// CopyAsMenu.swift (clipboard-interop CB-u1): the Edit menu's Copy As submenu
// (PNG, SVG, the app's own type, in that order) and its Paste as Image item,
// built from CopyAsCommands' specs through MenuCommand+Catalog. Each item
// takes its enabled state and help from the spec's availability on the
// target, so one that can't act is off and says why in the coder's or the
// document's sentence (no dead controls). The menu only reads its target; it
// calls `copy` and `pasteAsImage`, which the app routes through its pasteboard
// adapter. Placed inside an app's Edit menu.
import SuiteKernel
import SwiftUI

public struct CopyAsMenu<Target: CopyAsTarget>: View {
    /// One item: its command id (`edit.copy-as` or `edit.paste-as-image`), the format it copies, and the item.
    public struct Entry: Identifiable {
        public let commandID: String
        public let format: CopyAsFormat?
        public let command: MenuCommand
        /// The command id, plus the format for a Copy As item: "edit.copy-as.png".
        public var id: String { format.map { "\(commandID).\($0.rawValue)" } ?? commandID }
    }

    private let target: Target
    private let ownTitle: String
    private let copy: @MainActor (CopyAsFormat) -> Void
    private let pasteAsImage: @MainActor () -> Void

    /// `ownTitle` names the app's own type in the submenu ("Design Layers").
    public init(
        on target: Target, ownTitle: String, copy: @escaping @MainActor (CopyAsFormat) -> Void,
        pasteAsImage: @escaping @MainActor () -> Void
    ) {
        self.target = target
        self.ownTitle = ownTitle
        self.copy = copy
        self.pasteAsImage = pasteAsImage
    }

    private nonisolated static var specs: [CommandSpec<Target>] { CopyAsCommands.specs(Target.self) }

    /// The submenu's title for `format`.
    private func title(_ format: CopyAsFormat) -> String {
        switch format {
        case .png: "PNG"
        case .svg: "SVG"
        case .own: ownTitle
        }
    }

    /// Copy As's items, PNG, SVG and the own type; empty if the catalog has no `edit.copy-as`.
    public var copyItems: [Entry] {
        guard let spec = Self.specs.first(where: { $0.id == "edit.copy-as" }) else { return [] }
        return CopyAsFormat.allCases.map { format in
            let copy = self.copy
            return Entry(commandID: spec.id, format: format,
                         command: MenuCommand(spec, on: target, title: title(format)) { copy(format) })
        }
    }

    /// Paste as Image; nil if the catalog has no `edit.paste-as-image`.
    public var pasteItem: Entry? {
        guard let spec = Self.specs.first(where: { $0.id == "edit.paste-as-image" }) else { return nil }
        return Entry(commandID: spec.id, format: nil,
                     command: MenuCommand(spec, on: target, systemImage: "photo.on.rectangle", perform: pasteAsImage))
    }

    public var body: some View {
        let items = copyItems
        Menu("Copy As") {
            ForEach(items) { $0.command }
        }
        .disabled(!items.contains(where: \.command.isEnabled))
        .help(items.first(where: { !$0.command.isEnabled })?.command.help ?? "Copy the selection as PNG, SVG or \(ownTitle).")
        if let paste = pasteItem { paste.command }
    }
}
