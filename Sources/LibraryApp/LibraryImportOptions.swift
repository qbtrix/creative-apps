// LibraryImportOptions.swift (catalog-files LC-3, LC-7): the import panel's copy choice. Its `ImportCopyChoice`
// is the panel's own state, which the import takes once the panel closes; picking Copy starts at Pictures, and
// a second panel then picks the folder (LibraryWindow+Import.swift).
import Foundation
import LibraryModel
import SuiteUI
import SwiftUI

/// The copy choice the open panel's accessory edits; not the catalog's state.
@Observable final class ImportCopyChoice {
    var options: ImportCopyOptions
    init(_ options: ImportCopyOptions = ImportCopyOptions()) { self.options = options }

    /// The user's Pictures folder, where a copy starts.
    static var pictures: String {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first?.path(percentEncoded: false)
            ?? NSHomeDirectory()
    }
}

struct LibraryImportOptions: View {
    let choice: ImportCopyChoice

    var body: some View {
        let choice = self.choice
        let copying = Binding<Bool>(get: { choice.options.copyTo != nil }, set: { (copy: Bool) -> Void in
            choice.options.copyTo = copy ? ImportCopyChoice.pictures : nil
            if !copy { choice.options.byDate = false }
        })
        let dated = Binding<Bool>(get: { choice.options.byDate }, set: { (on: Bool) -> Void in choice.options.byDate = on })
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Picker("Import", selection: copying) {
                Text("Add in place").tag(false)
                Text("Copy to a folder").tag(true)
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("library.import.copy")
            Toggle("Into dated folders", isOn: dated)
                .toggleStyle(.checkbox)
                .disabled(choice.options.copyTo == nil)
                .accessibilityIdentifier("library.import.dated")
            Text(choice.options.summary).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .help("Add the photos where they are, or copy them into a folder first.")
        .padding(SuiteSpacing.m)
    }
}
