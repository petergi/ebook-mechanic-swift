import Foundation

final class ProgressPrinterTestHooks {
  private(set) var messages: [String] = []

  func append(_ message: String) {
    messages.append(message)
  }

  func contains(_ substring: String) -> Bool {
    messages.contains { $0.contains(substring) }
  }
}

extension ProgressPrinter {
  static func makeTestable(verbose: Bool) -> (ProgressPrinter, ProgressPrinterTestHooks) {
    let hooks = ProgressPrinterTestHooks()
    let printer = ProgressPrinter(verbose: verbose) { message in
      hooks.append(message)
    }
    return (printer, hooks)
  }
}
