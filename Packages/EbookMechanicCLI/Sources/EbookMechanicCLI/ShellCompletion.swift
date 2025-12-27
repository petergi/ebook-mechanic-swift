import Foundation

enum ShellType: String, CaseIterable {
  case bash
  case zsh
  case fish
  case powershell

  var displayName: String {
    switch self {
    case .powershell:
      return "PowerShell"
    default:
      return rawValue
    }
  }
}

struct ShellCompletion {
  static func generate(for shell: ShellType) {
    let script: String
    switch shell {
    case .bash:
      script = bashScript()
    case .zsh:
      script = zshScript()
    case .fish:
      script = fishScript()
    case .powershell:
      script = powerShellScript()
    }

    print(script)
  }

  private static func bashScript() -> String {
    let flags = allFlags.joined(separator: " ")
    let shells = shellList
    return """
# bash completion for ebook-mechanic
_ebook_mechanic_completions() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"
  local opts=\"\(flags)\"
  local shells=\"\(shells)\"
  COMPREPLY=( $(compgen -W "$opts $shells" -- "$cur") )
}
complete -F _ebook_mechanic_completions ebook-mechanic
"""
  }

  private static func zshScript() -> String {
    let options = zshOptions.joined(separator: " \\\n  ")
    return """
#compdef ebook-mechanic
_ebook_mechanic() {
  local -a options
  options=(
  \(options)
  )
  _arguments -s -S $options
}
_ebook_mechanic "$@"
"""
  }

  private static func fishScript() -> String {
    return fishOptions.joined(separator: "\n") + "\n"
  }

  private static func powerShellScript() -> String {
    let flags = powerShellFlags.joined(separator: ", ")
    return """
# PowerShell completion for ebook-mechanic
Register-ArgumentCompleter -Native -CommandName ebook-mechanic -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  $flags = @(
    \(flags)
  )
  $shells = @('bash', 'zsh', 'fish', 'powershell')
  $descriptions = @{
    '--help' = 'Show help message'
    '--dir' = 'Directory to scan'
    '--repair' = 'Attempt to repair corrupted files'
  }
  $flags | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
    $desc = $descriptions[$_]
    if (-not $desc) { $desc = $_ }
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $desc)
  }
}
"""
  }

  private static var shellList: String {
    ShellType.allCases.map { $0.rawValue }.joined(separator: " ")
  }

  private static var allFlags: [String] {
    [
      "--help", "-h",
      "--version", "-V",
      "--generate-completion",
      "--dir", "-d",
      "--corrupted-dir", "-c",
      "--corruption-only",
      "--empty-folders-only",
      "--repair", "-r",
      "--dry-run",
      "--no-confirm",
      "--quiet",
      "--report",
      "--normalize-epubs",
      "--force-normalize",
    ]
  }

  private static var zshOptions: [String] {
    [
      "'--help[Show help message]'",
      "'-h[Show help message]'",
      "'--version[Show version information]'",
      "'-V[Show version information]'",
      "'--generate-completion[Generate shell completion]:shell:(bash zsh fish powershell)'",
      "'--dir[Directory to scan]:directory:_directories'",
      "'-d[Directory to scan]:directory:_directories'",
      "'--corrupted-dir[Directory to move corrupted files]:directory:_directories'",
      "'-c[Directory to move corrupted files]:directory:_directories'",
      "'--corruption-only[Scan corrupted files only]'",
      "'--empty-folders-only[Scan empty folders only]'",
      "'--repair[Attempt to repair corrupted files]'",
      "'-r[Attempt to repair corrupted files]'",
      "'--dry-run[Do not modify files]'",
      "'--no-confirm[Skip confirmation prompts]'",
      "'--quiet[Disable verbose logging]'",
      "'--report[Generate report output]'",
      "'--normalize-epubs[Normalize EPUB files]'",
      "'--force-normalize[Force EPUB normalization]'",
    ]
  }

  private static var fishOptions: [String] {
    [
      "# fish completion for ebook-mechanic",
      "complete -c ebook-mechanic -s h -l help -d 'Show help message'",
      "complete -c ebook-mechanic -s V -l version -d 'Show version information'",
      "complete -c ebook-mechanic -l generate-completion -xa 'bash zsh fish powershell' -d 'Generate shell completion'",
      "complete -c ebook-mechanic -s d -l dir -r -d 'Directory to scan'",
      "complete -c ebook-mechanic -s c -l corrupted-dir -r -d 'Directory to move corrupted files'",
      "complete -c ebook-mechanic -l corruption-only -d 'Scan corrupted files only'",
      "complete -c ebook-mechanic -l empty-folders-only -d 'Scan empty folders only'",
      "complete -c ebook-mechanic -s r -l repair -d 'Attempt to repair corrupted files'",
      "complete -c ebook-mechanic -l dry-run -d 'Do not modify files'",
      "complete -c ebook-mechanic -l no-confirm -d 'Skip confirmation prompts'",
      "complete -c ebook-mechanic -l quiet -d 'Disable verbose logging'",
      "complete -c ebook-mechanic -l report -d 'Generate report output'",
      "complete -c ebook-mechanic -l normalize-epubs -d 'Normalize EPUB files'",
      "complete -c ebook-mechanic -l force-normalize -d 'Force EPUB normalization'",
    ]
  }

  private static var powerShellFlags: [String] {
    [
      "'-h'", "'--help'",
      "'-V'", "'--version'",
      "'--generate-completion'",
      "'-d'", "'--dir'",
      "'-c'", "'--corrupted-dir'",
      "'--corruption-only'",
      "'--empty-folders-only'",
      "'-r'", "'--repair'",
      "'--dry-run'",
      "'--no-confirm'",
      "'--quiet'",
      "'--report'",
      "'--normalize-epubs'",
      "'--force-normalize'",
    ]
  }
}
