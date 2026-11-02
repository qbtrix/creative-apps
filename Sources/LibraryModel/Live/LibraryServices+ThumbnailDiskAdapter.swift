// Live/LibraryServices+ThumbnailDiskAdapter.swift: shared-thumbnails ST-7,
// Library's half, an adapter onto the shared store. The window's live services draw the grid over the disk tier
// (`LiveThumbnailStoreAdapter`, ST-6) in `<support>/Library/Thumbnails`, so a
// relaunch reads its thumbnails instead of decoding them again. Only the live
// `LiveThumbnails` gains the tier: fakes (fixtures, previews) are left as they
// are, and so is everything when the store can't open (the grid then decodes
// as before). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

extension LibraryServices {
    /// The most bytes Library's grid keeps on disk before it drops the oldest thumbnails.
    public static let thumbnailDiskBudget = 512 * 1024 * 1024

    /// Library's thumbnail store: `<support>/Library/Thumbnails`, under `-SuiteSupportDir` when given.
    public static func thumbnailFolder(arguments: [String], home: String) -> String {
        SuiteLocations.appFolder("Library", arguments: arguments, home: home) + "/Thumbnails"
    }

    /// These services with the live grid thumbnails over the disk store in
    /// `folder`; unchanged when the thumbnails aren't live or the store won't open.
    public func withThumbnailDisk(folder: String, budgetBytes: Int = LibraryServices.thumbnailDiskBudget) -> LibraryServices {
        guard let live = thumbnails as? LiveThumbnails,
              let disk = try? LiveThumbnailStoreAdapter(folder: folder, budgetBytes: budgetBytes)
        else { return self }
        var services = self
        services.thumbnails = LiveThumbnails(decoder: live.decoder, develop: live.develop, disk: disk)
        return services
    }
}
