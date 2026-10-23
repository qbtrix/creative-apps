// LibraryWindow+Filters.swift: the filters and collections area
// (filters-collections FC-4). `LibraryFiltersMenu` is what the menu bar and
// the filter bar call on the focused window: every filter, collection and
// smart-collection action, each built as `enabled(help == nil)` from the
// catalog's help, so it lights up when a slice sets its `unavailable` to nil
// with no app edit. `LibraryFilterBar` draws the bar: Picked, Unflagged and
// Rejected chips, the rating and label menus, Hide Rejected, the summary
// and Clear; a control that can't act is disabled with its reason as help,
// and each is listed in `library.controls`.
// The hooks read `collections.json` at launch, write it 500 ms after each
// change, and flush it on quit; every state change is a LibraryCatalog
// method. FC-5 mounts the bar, publishes `\.libraryFilters` and calls the
// hooks.
import Foundation
import LibraryModel
import SuiteUI
import SwiftUI

/// The collections file's debounce and write guard.
final class FiltersAreaState {
    /// The debounce before a save; a newer change cancels it.
    var pending: Task<Void, Never>?
    /// True while a write is under way, so writes never overlap.
    var isSaving = false
}

/// What the menu bar and the filter bar call on the focused window. A nil
/// action disables its control; the matching help says why.
struct LibraryFiltersMenu {
    typealias Action = @MainActor () -> Void

    /// Photo > Add to Collection's item for one collection of yours.
    struct AddItem: Identifiable {
        let id: String
        let title: String
        var action: Action?
        var help: String?
    }

    // The filter bar.
    /// The rules in force, for View > Filter's checkmarks.
    var activeFilter = LibraryFilter.all
    var toggleFlag: (@MainActor (PhotoFlag) -> Void)?
    var setRating: (@MainActor (RatingRule) -> Void)?
    var toggleLabel: (@MainActor (PhotoLabel) -> Void)?
    var toggleHideRejected: Action?
    var clearFilter: Action?
    var filterHelp: String?
    var clearFilterHelp: String?

    // Collections.
    var newCollection: Action?
    var renameCollection: (@MainActor (_ id: String, _ name: String) -> Void)?
    var addPhotos: (@MainActor (_ ids: Set<String>, _ id: String) -> Void)?
    var addItems: [AddItem] = []
    var removeFromCollection: Action?
    var deleteCollection: (@MainActor (_ id: String) -> Void)?
    /// The selected collection of yours, which File > Delete Collection deletes.
    var selectedCollectionID: String?
    var collectionsHelp: String?
    var removeFromCollectionHelp: String?
    var deleteCollectionHelp: String?

    // Smart collections.
    var newSmartCollection: Action?
    var newSmartCollectionHelp: String?
}

extension FocusedValues {
    @Entry var libraryFilters: LibraryFiltersMenu?
}

extension LibraryWindow {
    var filtersMenu: LibraryFiltersMenu {
        let filterOK = model.filterHelp == nil
        let collectionsOK = UserCollection.unavailable == nil
        let addItems = model.userCollections.filter { !$0.isSmart }.map { collection in
            let help = model.addToCollectionHelp(collection.id)
            return LibraryFiltersMenu.AddItem(
                id: collection.id, title: collection.name,
                action: enabled(help == nil) { model.addToCollection(collection.id) }, help: help)
        }
        return LibraryFiltersMenu(
            activeFilter: model.activeFilter,
            toggleFlag: enabled(filterOK) { (flag: PhotoFlag) in model.toggleFilterFlag(flag) },
            setRating: enabled(filterOK) { (rule: RatingRule) in model.setRatingRule(rule) },
            toggleLabel: enabled(filterOK) { (label: PhotoLabel) in model.toggleFilterLabel(label) },
            toggleHideRejected: enabled(filterOK) { model.toggleHideRejected() },
            clearFilter: enabled(model.clearFilterHelp == nil) { model.clearFilter() },
            filterHelp: model.filterHelp,
            clearFilterHelp: model.clearFilterHelp,
            newCollection: enabled(collectionsOK) { _ = model.newCollection() },
            renameCollection: enabled(collectionsOK) { (id: String, name: String) in model.renameCollection(id, to: name) },
            addPhotos: enabled(collectionsOK) { (ids: Set<String>, id: String) in model.add(ids, to: id) },
            addItems: addItems,
            removeFromCollection: enabled(model.removeFromCollectionHelp == nil) { model.removeFromCollection() },
            deleteCollection: enabled(model.deleteCollectionHelp == nil) { (id: String) in model.deleteCollection(id) },
            selectedCollectionID: model.selectedUserCollection?.id,
            collectionsHelp: UserCollection.unavailable,
            removeFromCollectionHelp: model.removeFromCollectionHelp,
            deleteCollectionHelp: model.deleteCollectionHelp,
            newSmartCollection: enabled(model.newSmartCollectionHelp == nil) { _ = model.newSmartCollection() },
            newSmartCollectionHelp: model.newSmartCollectionHelp)
    }

    /// Where `collections.json` lives: the -LibraryCatalogDir folder, else
    /// Application Support/Library; nil in a preview, which writes nothing.
    var collectionsStore: CollectionsStore? {
        if let dir = LibraryLaunch(arguments: ProcessInfo.processInfo.arguments).catalogDir {
            return CollectionsStore(directory: dir)
        }
        return model.services.isPreview ? nil : CollectionsStore(directory: CatalogStore.defaultFolder.path)
    }

    /// Called once from the window's `.task`, after `persistAreaLaunch()`.
    func filtersAreaLaunch() {
        guard let store = collectionsStore else { return }
        Task {
            let data = await Task.detached(priority: .userInitiated) { try? await store.read() }.value
            do {
                try model.restoreCollections(data)
            } catch {
                let name = await Task.detached(priority: .utility) {
                    (try? await store.setAside()) ?? store.setAsideURL.path
                }.value
                model.failRestoreCollections(setAsideAs: name)
            }
        }
    }

    /// Called when `model.collectionsRevision` changes. FC-5 passes the
    /// window's `FiltersAreaState`.
    func filtersAreaChanged(_ state: FiltersAreaState) {
        state.pending?.cancel()
        state.pending = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            saveCollections(state)
        }
    }

    /// Called when the app is about to quit: the one blocking write.
    func filtersAreaFlush(_ state: FiltersAreaState) {
        state.pending?.cancel()
        guard let request = model.collectionsSaveRequest(), let store = collectionsStore else { return }
        do {
            try store.writeNow(request.data)
            model.didSaveCollections(revision: request.revision)
        } catch {
            // A failed write leaves the file dirty; the next change tries again.
        }
    }

    /// Writes what the catalog asks for off the main actor, then reports
    /// back; a change made during the write is saved right after it.
    private func saveCollections(_ state: FiltersAreaState) {
        guard !state.isSaving, let request = model.collectionsSaveRequest(), let store = collectionsStore else { return }
        state.isSaving = true
        Task {
            let saved = await Task.detached(priority: .utility) { () -> Bool in
                (try? await store.write(request.data)) != nil
            }.value
            state.isSaving = false
            guard saved else { return }
            model.didSaveCollections(revision: request.revision)
            saveCollections(state)
        }
    }
}

/// The filter bar above the grid: it reads the filter and calls the menu.
struct LibraryFilterBar: View {
    let filter: LibraryFilter
    let value: String
    let caption: String?
    let menu: LibraryFiltersMenu

    nonisolated static let flags: [PhotoFlag] = [.pick, .none, .reject]
    nonisolated static let ratings: [RatingRule] =
        [.any] + (1...5).map { RatingRule.atLeast($0) } + (0...5).map { RatingRule.exactly($0) }

    /// The chip's name: Picked, Unflagged, Rejected.
    nonisolated static func title(_ flag: PhotoFlag) -> String {
        switch flag {
        case .pick: "Picked"
        case .none: "Unflagged"
        case .reject: "Rejected"
        }
    }

    private var filterHelp: String { menu.filterHelp ?? "Show only the photos that pass these rules." }
    private var clearHelp: String { menu.clearFilterHelp ?? "Show every photo in the collection." }

    var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            if let caption {
                Text(caption).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            }
            // One ChipRow per chip, so each chip's button carries its own identifier.
            ForEach(Self.flags, id: \.self) { flag in
                ChipRow([ChipItem(id: flag, title: Self.title(flag), isOn: filter.flags.contains(flag))]) {
                    menu.toggleFlag?($0)
                }
                .disabled(menu.toggleFlag == nil)
                .help(filterHelp)
                .libraryControl(
                    id: "library.filter.flag.\(flag.rawValue.lowercased())", enabled: menu.toggleFlag != nil,
                    help: filterHelp)
            }
            Menu(filter.rating.title) {
                ForEach(Self.ratings, id: \.self) { rule in
                    Toggle(rule.title, isOn: Binding(get: { filter.rating == rule }, set: { _ in menu.setRating?(rule) }))
                }
            }
            .fixedSize()
            .disabled(menu.setRating == nil)
            .help(filterHelp)
            .libraryControl(id: "library.filter.rating", enabled: menu.setRating != nil, help: filterHelp)
            Toggle("Hide Rejected", isOn: Binding(get: { filter.hidesRejected }, set: { _ in menu.toggleHideRejected?() }))
                .toggleStyle(.checkbox)
                .disabled(menu.toggleHideRejected == nil)
                .help(filterHelp)
                .libraryControl(
                    id: "library.filter.hideRejected", enabled: menu.toggleHideRejected != nil, help: filterHelp)
            Menu(filter.labels.isEmpty ? "Any Label" : "Labels (\(filter.labels.count))") {
                ForEach(PhotoLabel.allCases, id: \.self) { label in
                    Toggle(label.rawValue, isOn: Binding(
                        get: { filter.labels.contains(label) }, set: { _ in menu.toggleLabel?(label) }))
                }
            }
            .fixedSize()
            .disabled(menu.toggleLabel == nil)
            .help(filterHelp)
            .libraryControl(id: "library.filter.label", enabled: menu.toggleLabel != nil, help: filterHelp)
            Spacer(minLength: SuiteSpacing.s)
            Text(value).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
            Button("Clear") { menu.clearFilter?() }
                .disabled(menu.clearFilter == nil)
                .help(clearHelp)
                .libraryControl(id: "library.filter.clear", enabled: menu.clearFilter != nil, help: clearHelp)
        }
        .padding(.horizontal, SuiteSpacing.m)
        .padding(.vertical, SuiteSpacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityValue(value)
        .accessibilityIdentifier("library.filter")
    }
}
