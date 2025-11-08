#if DEBUG
import Foundation

/// Debug-only helper that captures console output emitted by `ProgressPrinter`.
struct ProgressPrinterTestHooks {
    fileprivate let recorder: ProgressPrinterOutputRecorder

    /// All messages emitted through the printer, in order.
    var messages: [String] { recorder.messages }

    /// Convenience helper to check if a specific substring exists.
    func contains(_ fragment: String) -> Bool {
        messages.contains(where: { $0.contains(fragment) })
    }
}

final class ProgressPrinterOutputRecorder: @unchecked Sendable {
    private(set) var messages: [String] = []

    func record(_ text: String) {
        messages.append(text)
    }
}

extension ProgressPrinter {
    /// Factory that returns a printer wired to a debug recorder for assertions.
    static func makeTestable(verbose: Bool = true) -> (printer: ProgressPrinter, hooks: ProgressPrinterTestHooks) {
        let recorder = ProgressPrinterOutputRecorder()
        let printer = ProgressPrinter(verbose: verbose, sink: { recorder.record($0) })
        return (printer, ProgressPrinterTestHooks(recorder: recorder))
    }
}
#endif
