import Foundation
import Testing
@testable import TempuraCore

@Test("Single instance lock rejects concurrent acquisition")
func rejectsConcurrentAcquisition() throws {
    let lockPath = temporaryLockPath()

    let firstLock = try #require(SingleInstanceLock(path: lockPath))
    #expect(SingleInstanceLock(path: lockPath) == nil)

    _ = firstLock
}

@Test("Single instance lock can be acquired after release")
func canAcquireAfterRelease() throws {
    let lockPath = temporaryLockPath()

    do {
        let lock = try #require(SingleInstanceLock(path: lockPath))
        _ = lock
    }

    #expect(SingleInstanceLock(path: lockPath) != nil)
}

private func temporaryLockPath() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("tempura-\(UUID().uuidString).lock")
        .path
}
