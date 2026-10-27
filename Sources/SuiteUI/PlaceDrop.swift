// PlaceDrop.swift: the drop target that places images (placed-images PL-3). It takes file URLs and pasteboard PNG,
// JPEG or SVG data, highlights only while the drag offers an item of `formats` (a Finder file registers its content
// type beside its URL), and reads the files off the main actor through `PlaceReader`, which the panel shares. A file
// it highlighted for but then refused (over `PlaceRules.maxBytes`, or bytes that aren't the format) reports why through
// `onRefuse`, so no drop vanishes without a word.
import Foundation
import SuiteKernel
import SwiftUI
import UniformTypeIdentifiers

/// One thing to place: a file on disk, or bytes from the pasteboard with a name to show.
enum PlaceItem: Sendable {
    case file(URL), data(name: String, Data)
}

/// What a drop or the panel took, and why it refused the rest (nil when it took every item).
struct PlaceRead: Sendable {
    var taken: [(name: String, data: Data)] = []
    var refused: String?
}

/// The format and size checks every place source runs before a `.place` intent.
enum PlaceReader {
    /// The content type of each format.
    static func types(for formats: Set<PlacedFormat>) -> [UTType] {
        PlacedFormat.allCases.filter(formats.contains).map { format in
            switch format {
            case .png: .png
            case .jpeg: .jpeg
            case .svg: .svg
            }
        }
    }

    /// Whether a drag whose items register `registered` type identifiers highlights: one of them is of `formats`.
    static func takes(_ registered: [[String]], formats: Set<PlacedFormat>) -> Bool {
        let wanted = types(for: formats)
        return registered.contains { ids in
            ids.compactMap(UTType.init).contains { type in wanted.contains { type.conforms(to: $0) } }
        }
    }

    /// A drop at `point`: `items` read off the main actor, then what it took handed to `onPlace` with the point, and
    /// why it refused the rest to `onRefuse`.
    @MainActor static func drop(
        _ items: [PlaceItem], at point: CGPoint, formats: Set<PlacedFormat>,
        onPlace: @MainActor ([(name: String, data: Data)], CGPoint) -> Bool,
        onRefuse: @MainActor (String) -> Void = { _ in }
    ) async -> PlaceRead {
        let read = await read(items, formats: formats)
        if !read.taken.isEmpty { _ = onPlace(read.taken, point) }
        if let refused = read.refused { onRefuse(refused) }
        return read
    }

    /// `items` read off the main actor.
    static func read(_ items: [PlaceItem], formats: Set<PlacedFormat>) async -> PlaceRead {
        await Task.detached(priority: .userInitiated) { readNow(items, formats: formats) }.value
    }

    /// Each item of `formats` up to `PlaceRules.maxBytes`; the last refusal's reason for the rest.
    static func readNow(_ items: [PlaceItem], formats: Set<PlacedFormat>) -> PlaceRead {
        var read = PlaceRead()
        for item in items {
            switch item {
            case .file(let url):
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                guard size <= PlaceRules.maxBytes else { read.refused = PlaceRules.sizeHelp; continue }
                guard let data = try? Data(contentsOf: url) else { read.refused = PlaceRules.formatHelp; continue }
                take(url.lastPathComponent, data, formats: formats, into: &read)
            case .data(let name, let data):
                take(name, data, formats: formats, into: &read)
            }
        }
        return read
    }

    private static func take(_ name: String, _ data: Data, formats: Set<PlacedFormat>, into read: inout PlaceRead) {
        guard data.count <= PlaceRules.maxBytes else { read.refused = PlaceRules.sizeHelp; return }
        guard let format = PlaceRules.format(of: data), formats.contains(format) else {
            read.refused = PlaceRules.formatHelp
            return
        }
        read.taken.append((name, data))
    }

    /// The items `providers` offer: a file URL where there is one, else the first data of `formats`.
    @MainActor static func items(_ providers: [NSItemProvider], formats: Set<PlacedFormat>) async -> [PlaceItem] {
        var items: [PlaceItem] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
                let bytes = await load(provider, UTType.fileURL.identifier),
                let url = URL(dataRepresentation: bytes, relativeTo: nil)
            {
                items.append(.file(url))
            } else if let type = types(for: formats).first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }),
                let bytes = await load(provider, type.identifier)
            {
                items.append(.data(name: "Pasted Image.\(type.preferredFilenameExtension ?? "png")", bytes))
            }
        }
        return items
    }

    @MainActor private static func load(_ provider: NSItemProvider, _ id: String) async -> Data? {
        await withCheckedContinuation { done in
            _ = provider.loadDataRepresentation(forTypeIdentifier: id) { data, _ in done.resume(returning: data) }
        }
    }
}

extension View {
    /// Files and image or SVG data dropped from Finder or another app; `onPlace` gets each with the drop point, and
    /// `onRefuse` the reason when a file was too large or not a format it takes (`PlaceRules.sizeHelp`, `formatHelp`).
    public func placeDropTarget(
        formats: Set<PlacedFormat>, onPlace: @escaping @MainActor ([(name: String, data: Data)], CGPoint) -> Bool,
        onRefuse: @escaping @MainActor (String) -> Void = { _ in }
    ) -> some View {
        modifier(PlaceDropModifier(formats: formats, onPlace: onPlace, onRefuse: onRefuse))
    }
}

/// The drop and its highlight: an accent ring while the drag offers something it takes.
private struct PlaceDropModifier: ViewModifier {
    let formats: Set<PlacedFormat>
    let onPlace: @MainActor ([(name: String, data: Data)], CGPoint) -> Bool
    let onRefuse: @MainActor (String) -> Void
    @State private var targeted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if targeted {
                    RoundedRectangle(cornerRadius: SuiteRadius.medium).stroke(SuiteColor.accent, lineWidth: SuiteSize.focusRing)
                        .allowsHitTesting(false)
                }
            }
            .onDrop(
                of: [.fileURL] + PlaceReader.types(for: formats),
                delegate: PlaceDropDelegate(formats: formats, targeted: $targeted, onPlace: onPlace, onRefuse: onRefuse))
    }
}

private struct PlaceDropDelegate: DropDelegate {
    let formats: Set<PlacedFormat>
    let targeted: Binding<Bool>
    let onPlace: @MainActor ([(name: String, data: Data)], CGPoint) -> Bool
    let onRefuse: @MainActor (String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL] + PlaceReader.types(for: formats))
        return PlaceReader.takes(providers.map(\.registeredTypeIdentifiers), formats: formats)
    }

    func dropEntered(info: DropInfo) { targeted.wrappedValue = validateDrop(info: info) }

    func dropExited(info: DropInfo) { targeted.wrappedValue = false }

    func performDrop(info: DropInfo) -> Bool {
        targeted.wrappedValue = false
        let providers = info.itemProviders(for: [.fileURL] + PlaceReader.types(for: formats))
        let (formats, point, onPlace, onRefuse) = (formats, info.location, onPlace, onRefuse)
        Task { @MainActor in
            let items = await PlaceReader.items(providers, formats: formats)
            _ = await PlaceReader.drop(items, at: point, formats: formats, onPlace: onPlace, onRefuse: onRefuse)
        }
        return validateDrop(info: info)
    }
}
