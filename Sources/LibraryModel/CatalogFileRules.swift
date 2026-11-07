// CatalogFileRules.swift (catalog-files LC-1 stubs, LC-6 bodies): Remove drops photos from the catalog, no file
// touched. Relink maps the located photo's old folder to the picked file's: each missing photo under the old folder
// plus "/" maps to the same relative path in the new one when that file has the same size. Linux-safe.

/// Remove from Catalog's and Relink's rules over the catalog's photos.
public enum CatalogFileRules {
    /// `photos` without those whose id is in `ids`, the rest in order.
    public static func removing(_ ids: Set<String>, from photos: [PhotoItem]) -> [PhotoItem] {
        photos.filter { !ids.contains($0.id) }
    }

    /// The new path for each missing photo under `oldFolder`, when `newFolder` holds a file of the same name and size.
    /// Keyed by photo id, the located photo included; `size` answers a missing photo's recorded size by its old
    /// path and a candidate's size on disk by its new one, nil when unknown. A candidate with no size is not
    /// there; an old size that is unknown matches any. Empty when the located photo is not in `missing`.
    public static func relinks(missing: [PhotoItem], located: (id: String, file: String),
                               size: (String) -> Int?) -> [String: String] {
        guard let photo = missing.first(where: { $0.id == located.id }), let oldPath = photo.path else { return [:] }
        let oldFolder = parent(oldPath), newFolder = parent(located.file)
        var map = [located.id: located.file]
        let prefix = oldFolder + "/"
        for other in missing where other.id != located.id {
            guard let path = other.path, path.hasPrefix(prefix) else { continue }
            let candidate = newFolder + "/" + path.dropFirst(prefix.count)
            guard let found = size(candidate) else { continue }
            if let recorded = size(path), recorded != found { continue }
            map[other.id] = candidate
        }
        return map
    }

    /// "/cards/shoot" for "/cards/shoot/IMG_0001.jpg"; "" for a file at the root or a bare name.
    static func parent(_ path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return String(path[..<slash])
    }
}
