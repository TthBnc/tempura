import Darwin
import Foundation

public final class SingleInstanceLock: @unchecked Sendable {
    private let fileDescriptor: CInt

    public static func tempura() -> SingleInstanceLock? {
        let lockDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("com.tebe.tempura", isDirectory: true)

        guard let lockDirectory else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(
                at: lockDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return nil
        }

        return SingleInstanceLock(
            path: lockDirectory.appendingPathComponent("Tempura.lock").path
        )
    }

    public init?(path: String) {
        let fileDescriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            return nil
        }

        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(fileDescriptor)
            return nil
        }

        self.fileDescriptor = fileDescriptor
    }

    deinit {
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }
}
