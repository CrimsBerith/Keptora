import Foundation

struct CoordinatedFileMover: Sendable {
    private static let ioQueue = DispatchQueue(label: "com.alfagolab.keptora.file-mover", qos: .userInitiated)

    enum MoveError: LocalizedError {
        case coordination(String)
        case move(String)

        var errorDescription: String? {
            switch self {
            case .coordination(let message): return "File coordination failed: \(message)"
            case .move(let message): return "File move failed: \(message)"
            }
        }
    }

    func moveItem(from source: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.ioQueue.async {
                do {
                    try performMove(from: source, to: destination)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performMove(from source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let destinationParent = destination.deletingLastPathComponent()
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        var didRun = false

        coordinator.coordinate(
            writingItemAt: source,
            options: .forMoving,
            writingItemAt: destinationParent,
            options: [],
            error: &coordinationError
        ) { coordinatedSource, coordinatedParent in
            didRun = true
            let coordinatedDestination = coordinatedParent.appendingPathComponent(destination.lastPathComponent, isDirectory: false)
            do {
                coordinator.item(at: coordinatedSource, willMoveTo: coordinatedDestination)
                try FileManager.default.moveItem(at: coordinatedSource, to: coordinatedDestination)
                coordinator.item(at: coordinatedSource, didMoveTo: coordinatedDestination)
            } catch {
                operationError = error
            }
        }

        if let coordinationError { throw MoveError.coordination(coordinationError.localizedDescription) }
        guard didRun else { throw MoveError.coordination("The coordinated accessor did not run.") }
        if let operationError { throw MoveError.move(operationError.localizedDescription) }
    }
}
