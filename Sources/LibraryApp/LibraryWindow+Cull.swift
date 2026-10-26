// LibraryWindow+Cull.swift: the cull area. The single keys 0–5, P, X and U
// cull the loupe's photo or the selection (`LibraryAction.cull`, Auto
// Advance moving the loupe on); Set Rating, Set Flag and Set Label in the
// Metadata menu and the inspector are enabled while there is something to
// cull (`cullHelp` nil); Metadata > Auto Advance is a checkmark that follows
// the model; a refused change's notice closes through `dismissCullError`.
// Each runs through the catalog's `run`, which refuses what `help` names.
// The sidecar part (metadata-more MD-18): once the launch read lands, every
// photo then in the catalog counts as written; after each change the
// catalog's `sidecarWrites` plan is written off the main actor through
// `services.sidecars` (XMPSidecarWriter on a live launch). A write that
// fails is tried again only once that photo's fields change, so a sidecar
// another app wrote is never retried in a loop. A photo already being written
// waits for that write; a change made meanwhile is planned right after it.
import LibraryModel
import SwiftUI

/// What the sidecar writes know; the catalog holds the rest.
final class CullAreaState {
    /// Each photo's fields as its sidecar last said them; nil until the launch read lands.
    var written: [String: SidecarFields]?
    /// The photos whose sidecar is being written now.
    var writing: Set<String> = []
    /// The fields whose write failed, per photo; not tried again until they change.
    var failed: [String: SidecarFields] = [:]
}

extension LibraryWindow {
    var cullMenu: LibraryMenu.Cull {
        let canCull = model.cullHelp == nil
        return LibraryMenu.Cull(
            key: { key in
                if let change = model.cullChange(forKey: key) { try? model.run(.cull(change)) }
            },
            setRating: enabled(canCull) { (stars: Int) in try? model.run(.setRating(stars)) },
            setFlag: enabled(canCull) { (flag: PhotoFlag) in try? model.run(.setFlag(flag)) },
            setLabel: enabled(canCull) { (label: PhotoLabel?) in try? model.run(.setLabel(label)) },
            toggleAutoAdvance: { try? model.run(.toggleAutoAdvance) },
            autoAdvance: model.autoAdvance,
            dismissCullError: { try? model.run(.dismissCullError) })
    }
}

extension LibraryWindow {
    /// Called when `model.catalogState` changes: the launch read's photos count as written.
    func cullAreaCatalogReady() {
        guard model.catalogState != .loading, areas.cull.written == nil else { return }
        areas.cull.written = Dictionary(uniqueKeysWithValues: model.items.map { ($0.id, SidecarFields(photo: $0)) })
    }

    /// Called when `model.saveRevision` changes: writes the sidecars the change asks for.
    func cullAreaChanged() {
        let state = areas.cull
        guard let written = state.written else { return }
        let plan = model.sidecarWrites(after: written).filter {
            !state.writing.contains($0.photoID) && state.failed[$0.photoID] != $0.fields
        }
        guard !plan.isEmpty else { return }
        state.writing.formUnion(plan.map(\.photoID))
        let sidecars = model.services.sidecars
        Task {
            let results = await Task.detached(priority: .utility) { await Self.writeSidecars(plan, with: sidecars) }.value
            for (write, failure) in results {
                state.writing.remove(write.photoID)
                if failure == nil { state.written?[write.photoID] = write.fields }
                state.failed[write.photoID] = failure == nil ? nil : write.fields
            }
            cullAreaChanged()
        }
    }

    /// Writes each sidecar in `plan`; each write and its failure's sentence (nil: written).
    nonisolated static func writeSidecars(_ plan: [SidecarWrite], with sidecars: any SidecarWriting) async
        -> [(write: SidecarWrite, failure: String?)] {
        var results: [(write: SidecarWrite, failure: String?)] = []
        for write in plan {
            do {
                try await sidecars.write(write.data, sidecar: write.path)
                results.append((write, nil))
            } catch {
                results.append((write, (error as? LibraryError)?.message ?? "Couldn't write \(write.path)."))
            }
        }
        return results
    }
}
