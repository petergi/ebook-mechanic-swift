using namespace System.Management.Automation

Register-ArgumentCompleter -Native -CommandName ebook-mechanic -ScriptBlock {
  param($commandName, $wordToComplete, $cursorPosition)

  $options = @(
    "--help",
    "--version",
    "--dir",
    "--corrupted-dir",
    "--corruption-only",
    "--empty-folders-only",
    "--repair",
    "--dry-run",
    "--auto-confirm",
    "--verbose",
    "--report",
    "--report-format",
    "--report-formats",
    "--use-epubcheck",
    "--external-tools",
    "--max-concurrent",
    "--no-cache",
    "--performance-stats",
    "--normalize-epubs",
    "--force-normalize"
  )

  $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
    [CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}
