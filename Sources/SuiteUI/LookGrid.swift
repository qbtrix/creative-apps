// LookGrid.swift (adjust-everywhere AJ-4): the looks every app shows on a
// PresetGrid, the six built-in looks first, then the ones saved in the suite's
// preset store (LookGridRows). A click picks a look and applies it when the
// target's `look.apply` can run; while it can't, the grid's tooltip says why.
// Save Look… opens a name field whose Save says why a name can't be saved
// (empty, taken ignoring case, too long); Delete, shown only for a picked
// saved look (a built-in has none), asks first. The actions are the catalog's
// look commands on the host's AdjustTarget. Owns presentation state only: the
// picked look, the name being typed and the look awaiting a confirm.
// Controls carry `suite.looks.*` identifiers.
import Foundation
import SuiteImaging
import SuiteKernel
import SuiteModel
import SwiftUI

/// The grid's looks and what each may do.
public struct LookGridRows: Hashable, Sendable {
    public let looks: [LookPreset]

    /// The built-in looks, then each readable saved look whose id isn't a built-in's, in the store's order.
    public init(_ store: any PresetStoring) {
        let saved = store.list(kind: LookPreset.recordKind).compactMap { r -> LookPreset? in
            guard BuiltInLooks.look(r.id) == nil, var look = try? JSONDecoder().decode(LookPreset.self, from: r.payload)
            else { return nil }
            (look.id, look.name, look.builtIn) = (r.id, r.name, false)
            return look
        }
        looks = BuiltInLooks.all + saved
    }

    public var options: [InspectorOption<String>] {
        looks.map { InspectorOption(id: $0.id, title: $0.name, identifier: "suite.looks.look.\($0.id)") }
    }

    /// True for a saved look; a built-in look has no Delete.
    public func canDelete(_ id: String) -> Bool { looks.contains { $0.id == id && !$0.builtIn } }

    /// Why `name` can't be saved as a new look; nil when it can.
    public func saveHelp(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Name the look." }
        if trimmed.count > 64 { return "A look's name is at most 64 characters." }
        if looks.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            return "You already have a look named \u{201C}\(trimmed)\u{201D}."
        }
        return nil
    }

    /// `look` saved under `name`, as the store keeps it.
    public static func record(_ look: LookPreset, name: String) throws -> PresetRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = "saved-" + trimmed.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        var saved = look
        (saved.id, saved.name, saved.builtIn) = (id, trimmed, false)
        return PresetRecord(id: id, name: trimmed, kind: LookPreset.recordKind, payload: try JSONEncoder().encode(saved))
    }
}

public struct LookGrid<Target: AdjustTarget>: View {
    let rows: LookGridRows
    /// What the look commands' availability reads.
    let target: Target
    let onApply: @MainActor (String) -> Void
    let onSave: @MainActor (String) -> Void
    let onDelete: @MainActor (String) -> Void
    @State private var picked: String?
    /// The name being typed; nil while the field is closed.
    @State private var naming: String?
    @State private var deleting: String?

    public init(
        rows: LookGridRows, target: Target, onApply: @escaping @MainActor (String) -> Void = { _ in },
        onSave: @escaping @MainActor (String) -> Void = { _ in }, onDelete: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        (self.rows, self.target, self.onApply, self.onSave, self.onDelete) = (rows, target, onApply, onSave, onDelete)
    }

    private func spec(_ id: String) -> CommandSpec<Target>? { AdjustCommands.specs(Target.self).first { $0.id == id } }

    public var body: some View {
        let applyWhy = spec("look.apply")?.availability(target).why
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            PresetGrid(options: rows.options, selected: picked) { id in
                picked = id
                if applyWhy == nil { onApply(id) }
            }
            .help(applyWhy.map { "Apply Look: \($0)" } ?? "Click a look to apply it.")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("suite.looks")
            if let name = naming {
                nameField(name)
            } else if let save = spec("look.save") {
                InspectorAction(ToolbarAction(save, on: target, title: "Save Look…", systemImage: "plus",
                                              identifier: "suite.looks.save") { naming = "" })
            }
            if let id = picked, rows.canDelete(id), let delete = spec("look.delete") {
                InspectorAction(ToolbarAction(delete, on: target, title: "Delete", systemImage: "trash",
                                              identifier: "suite.looks.delete") { deleting = id })
            }
        }
        .confirmationDialog(
            "Delete This Look?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible, presenting: deleting
        ) { id in
            Button("Delete", role: .destructive) {
                picked = nil
                onDelete(id)
            }
            .accessibilityIdentifier("suite.looks.delete.confirm")
            Button("Cancel", role: .cancel) {}.accessibilityIdentifier("suite.looks.delete.cancel")
        } message: { id in
            Text("\u{201C}\(rows.looks.first { $0.id == id }?.name ?? id)\u{201D} is removed from every app.")
        }
    }

    private func nameField(_ name: String) -> some View {
        let why = rows.saveHelp(name)
        return HStack(spacing: SuiteSpacing.s) {
            TextField("Look Name", text: Binding(get: { naming ?? "" }, set: { naming = $0 }))
                .labelsHidden()
                .onSubmit { if why == nil { finish(name) } }
                .accessibilityLabel("Look Name")
                .accessibilityIdentifier("suite.looks.name")
            InspectorAction(ToolbarAction("Cancel", systemImage: "xmark", identifier: "suite.looks.name.cancel") { naming = nil },
                            iconOnly: true)
            InspectorAction(ToolbarAction("Save", systemImage: "checkmark", unavailableHelp: why,
                                          identifier: "suite.looks.name.save") { finish(name) }, iconOnly: true)
        }
    }

    private func finish(_ name: String) {
        naming = nil
        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
