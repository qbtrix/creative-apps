// CatalogFileRules.swift (catalog-files LC-1 stubs, LC-6 bodies): Remove drops photos from the catalog, no file
// touched. Relink maps the located photo's old folder to the picked file's: each missing photo under the old folder
// plus "/" maps to the same relative path in the new one when that file has the same size. Linux-safe.

/// Remove from Catalog's and Relink's rules over the catalog's photos.
public enum CatalogFileRules {
    /// `photos` without those whose id is in `ids`, the rest in order. LC-1: `photos` unchanged.
    public static func removing(_ ids: Set<String>, from photos: [PhotoItem]) -> [PhotoItem] {
        photos
    }

    /// The new path for each missing photo under `oldFolder`, when `newFolder` holds a file of the same name and size.
    /// Keyed by photo id, the located photo included; `size` answers a missing photo's recorded size by its old
    /// path and a candidate's size on disk by its new one, nil when unknown. LC-1: none.
    public static func relinks(missing: [PhotoItem], located: (id: String, file: String),
                               size: (String) -> Int?) -> [String: String] {
        [:]
    }
}
