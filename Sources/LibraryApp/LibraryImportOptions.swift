// LibraryImportOptions.swift (catalog-files LC-3): the import panel's copy choice, its own state until the
// import takes it (LC-7). While `help` says why copying can't run, every control is disabled with it.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryImportOptions: View {
    /// Why the copy choice can't change the import yet; nil once copying lands.
    var help: String? = LibraryCatalog.catalogFilesHelp
    @State private var options = ImportCopyOptions()

    var body: some View {
        let copying = Binding<Bool>(get: { options.copyTo != nil },
                                    set: { (copy: Bool) -> Void in options.copyTo = copy ? "Photos" : nil })
        let dated = Binding<Bool>(get: { options.byDate }, set: { (on: Bool) -> Void in options.byDate = on })
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Picker("Import", selection: copying) {
                Text("Add in place").tag(false)
                Text("Copy to a folder").tag(true)
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("library.import.copy")
            Toggle("Into dated folders", isOn: dated)
                .toggleStyle(.checkbox)
                .disabled(options.copyTo == nil)
                .accessibilityIdentifier("library.import.dated")
            Text(options.summary).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .disabled(help != nil)
        .help(help ?? "Add the photos where they are, or copy them into a folder first.")
        .padding(SuiteSpacing.m)
    }
}
