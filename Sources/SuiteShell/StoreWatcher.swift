// StoreWatcher.swift: tells the other suite processes that a store file
// changed, and hears it from them (blueprint 2.6, shell-store-watch). A post
// names the file; an observer of that name runs in every process that set one.
// Static because an observer lives as long as its process.
import Foundation

public enum StoreWatcher {
    static let name = Notification.Name("org.creativesuite.store-changed")

    public static func post(_ file: String) {
        DistributedNotificationCenter.default().postNotificationName(name, object: file, userInfo: nil, deliverImmediately: true)
    }

    /// Runs `action` each time any process posts a change to `file`.
    public static func observe(_ file: String, _ action: @escaping @Sendable () -> Void) {
        DistributedNotificationCenter.default().addObserver(forName: name, object: file, queue: nil) { _ in action() }
    }
}
