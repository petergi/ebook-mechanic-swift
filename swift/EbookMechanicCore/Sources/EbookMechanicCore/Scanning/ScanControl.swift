import Foundation

/// Coordinates pause/resume for long-running scan operations.
public actor ScanControl {
  private var isPaused: Bool = false
  private var continuations: [CheckedContinuation<Void, Never>] = []

  public init() {}

  public func pause() {
    isPaused = true
  }

  public func resume() {
    isPaused = false
    let pending = continuations
    continuations.removeAll()
    for continuation in pending {
      continuation.resume()
    }
  }

  public func waitIfPaused() async {
    guard isPaused else { return }
    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }
  }
}
