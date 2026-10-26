// LibraryHeadlessStackTests.swift (#5032): opening and copying a LibraryHeadless must fit a secondary thread's
// small stack (512 KB, Linux's default for non-main threads). The catalog's state used to be stored inline, so a
// copy moved several KB of stack per frame and crashed with signal 11 on Linux; it now sits behind a reference.
// Also pins the inline sizes so the struct can't quietly grow back. Linux-safe.
import Foundation
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryHeadlessStackTests {
    /// Runs `body` on a thread with a `stackSize`-byte stack and waits for it.
    static func onSmallStack(_ stackSize: Int, _ body: @escaping @Sendable () -> Void) {
        let done = DispatchSemaphore(value: 0)
        let thread = Thread { body(); done.signal() }
        thread.stackSize = stackSize
        thread.start()
        done.wait()
    }

    @inline(never) static func copied(_ doc: LibraryHeadless) -> LibraryHeadless { let copy = doc; return copy }

    static var sizes: String {
        "#5032 MemoryLayout sizes: LibraryHeadless \(MemoryLayout<LibraryHeadless>.size), "
            + "LibraryCatalog \(MemoryLayout<LibraryCatalog>.size), LibraryServices \(MemoryLayout<LibraryServices>.size)\n"
    }

    /// A copy is a pointer copy, not the whole catalog.
    @Test func headlessStaysSmall() {
        #expect(MemoryLayout<LibraryHeadless>.size <= 64, "\(Self.sizes)")
    }

    @Test(arguments: [512, 256]) func openAndCopyOnASmallStackThread(kilobytes: Int) throws {
        FileHandle.standardError.write(Data(Self.sizes.utf8))  // before the thread: a crash loses buffered stdout
        let data = try Data(contentsOf: LibraryJob.root.appendingPathComponent("cull-and-save/input/shoot.library"))
        let result = LockedResult()
        Self.onSmallStack(kilobytes * 1024) {
            guard var doc = try? LibraryHeadless.open(data, name: "shoot.library") else { return }
            let before = doc.library.items
            let copy = Self.copied(doc)
            _ = try? LibraryHeadless.catalog.run("edit.select", params: .object(["ids": .array([.string("fog")])]), on: &doc)
            _ = try? LibraryHeadless.catalog.run("metadata.set-rating", params: .object(["stars": .number(3)]), on: &doc)
            result.set(copyUnchanged: copy.library.items == before,
                       rating: doc.library.items.first { $0.id == "fog" }?.rating)
        }
        // Value semantics: rating the original leaves the copy as it was.
        #expect(result.value.copyUnchanged == true)
        #expect(result.value.rating == 3)
    }
}

/// The thread's result, read back after the semaphore.
final class LockedResult: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: (copyUnchanged: Bool?, rating: Int?) = (nil, nil)
    var value: (copyUnchanged: Bool?, rating: Int?) { lock.lock(); defer { lock.unlock() }; return stored }
    func set(copyUnchanged: Bool, rating: Int?) { lock.lock(); stored = (copyUnchanged, rating); lock.unlock() }
}
