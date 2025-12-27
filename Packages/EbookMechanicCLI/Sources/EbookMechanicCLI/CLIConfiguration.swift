import Foundation

enum CLIError: Error, Equatable {
  case invalidArgument(String)
  case userRequestedHelp
  case userRequestedVersion
  case userRequestedCompletion(ShellType)
}

struct CLIConfiguration: Equatable {
  var directory: String
  var corruptedDirectory: String
  var corruptionOnly: Bool
  var emptyFoldersOnly: Bool
  var repair: Bool
  var dryRun: Bool
  var autoConfirm: Bool
  var verbose: Bool
  var generateReport: Bool
  var reportFormats: [String]
  var externalTools: Bool
  var maxConcurrent: Int
  var noCache: Bool
  var performanceStats: Bool
  var normalizeEPUBs: Bool
  var forceNormalize: Bool

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  static func parse(arguments: [String]) throws -> CLIConfiguration {
    var config = CLIConfiguration(
      directory: FileManager.default.currentDirectoryPath,
      corruptedDirectory: "CORRUPTED",
      corruptionOnly: false,
      emptyFoldersOnly: false,
      repair: false,
      dryRun: false,
      autoConfirm: false,
      verbose: true,
      generateReport: false,
      reportFormats: ["markdown"],
      externalTools: false,
      maxConcurrent: ProcessInfo.processInfo.activeProcessorCount,
      noCache: false,
      performanceStats: false,
      normalizeEPUBs: false,
      forceNormalize: false
    )

    var index = 1
    while index < arguments.count {
      let argument = arguments[index]
      switch argument {
      case "--help", "-h":
        throw CLIError.userRequestedHelp
      case "--version", "-V":
        throw CLIError.userRequestedVersion
      case "--generate-completion":
        guard index + 1 < arguments.count else {
          throw CLIError.invalidArgument("Missing shell type for --generate-completion")
        }
        let shellValue = arguments[index + 1]
        index += 1
        let normalized = shellValue.lowercased()
        guard let shell = ShellType(rawValue: normalized) else {
          throw CLIError.invalidArgument("Unknown shell type: \(shellValue)")
        }
        throw CLIError.userRequestedCompletion(shell)
      case "--dir", "-d":
        guard index + 1 < arguments.count else {
          throw CLIError.invalidArgument("Missing value for \(argument)")
        }
        config.directory = arguments[index + 1]
        index += 1
      case "--corrupted-dir", "-c":
        guard index + 1 < arguments.count else {
          throw CLIError.invalidArgument("Missing value for \(argument)")
        }
        config.corruptedDirectory = arguments[index + 1]
        index += 1
      case "--corruption-only":
        if !config.emptyFoldersOnly {
          config.corruptionOnly = true
        }
      case "--empty-folders-only":
        config.emptyFoldersOnly = true
        config.corruptionOnly = false
      case "--repair", "-r":
        config.repair = true
      case "--dry-run":
        config.dryRun = true
      case "--no-confirm":
        config.autoConfirm = true
      case "--quiet":
        config.verbose = false
      case "--report":
        config.generateReport = true
      case "--report-formats":
        guard index + 1 < arguments.count else {
          throw CLIError.invalidArgument("Missing value for \(argument)")
        }
        let rawFormats = arguments[index + 1]
        index += 1
        config.reportFormats = rawFormats
          .split(separator: ",")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
          .filter { !$0.isEmpty }
      case "--external-tools":
        config.externalTools = true
      case "--max-concurrent":
        guard index + 1 < arguments.count else {
          throw CLIError.invalidArgument("Missing value for \(argument)")
        }
        let rawValue = arguments[index + 1]
        index += 1
        guard let value = Int(rawValue), value > 0 else {
          throw CLIError.invalidArgument("Invalid value for \(argument): \(rawValue)")
        }
        config.maxConcurrent = value
      case "--no-cache":
        config.noCache = true
      case "--performance-stats":
        config.performanceStats = true
      case "--normalize-epubs":
        config.normalizeEPUBs = true
      case "--force-normalize":
        config.forceNormalize = true
        config.normalizeEPUBs = true
      default:
        if argument.hasPrefix("-") {
          throw CLIError.invalidArgument("Unknown argument: \(argument)")
        } else {
          throw CLIError.invalidArgument("Unknown argument: \(argument)")
        }
      }

      index += 1
    }

    return config
  }
}
