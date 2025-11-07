package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Styles
var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("205")).
			MarginTop(1).
			MarginBottom(1)

	statusStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241"))

	successStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("42")).
			Bold(true)

	errorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("196")).
			Bold(true)

	infoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("86"))

	statsStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("63")).
			Padding(1, 2).
			MarginTop(1)

	headerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("212"))
)

// handleCompletion handles the completion subcommand
func handleCompletion(args []string) {
	if len(args) == 0 {
		fmt.Println("Usage: ebook-mechanic completion <shell>")
		fmt.Println("Available shells: bash, zsh, fish, powershell")
		fmt.Println()
		fmt.Println("Examples:")
		fmt.Println("  # Install bash completion")
		fmt.Println("  ebook-mechanic completion bash > /etc/bash_completion.d/ebook-mechanic")
		fmt.Println()
		fmt.Println("  # Install zsh completion")
		fmt.Println("  ebook-mechanic completion zsh > ~/.zsh_completion/_ebook-mechanic")
		fmt.Println()
		fmt.Println("  # Install fish completion")
		fmt.Println("  ebook-mechanic completion fish > ~/.config/fish/completions/ebook-mechanic.fish")
		fmt.Println()
		fmt.Println("  # Install PowerShell completion")
		fmt.Println("  ebook-mechanic completion powershell > ebook-mechanic.ps1")
		os.Exit(0)
	}

	shell := strings.ToLower(args[0])
	switch shell {
	case "bash":
		fmt.Print(bashCompletion())
	case "zsh":
		fmt.Print(zshCompletion())
	case "fish":
		fmt.Print(fishCompletion())
	case "powershell", "pwsh":
		fmt.Print(powershellCompletion())
	default:
		fmt.Fprintf(os.Stderr, "Error: Unsupported shell '%s'. Supported shells: bash, zsh, fish, powershell\n", shell)
		os.Exit(1)
	}
}

// Phase represents different stages of the application
type Phase int

const (
	PhaseInit Phase = iota
	PhaseScanning
	PhaseRepairing
	PhaseNormalizing
	PhaseMoving
	PhaseScanningFolders
	PhaseDeleting
	PhaseGeneratingReport
	PhaseDone
)

// model represents the application state
type model struct {
	scanner          *FileScanner
	phase            Phase
	progress         progress.Model
	spinner          spinner.Model
	current          int
	total            int
	currentItem      string
	err              error
	corruptionOnly   bool
	emptyFoldersOnly bool
	dryRun           bool
	noConfirm        bool
	repair           bool
	normalizeEPUB    bool
	forceNormalize   bool
	keepBackups      bool
	confirmed        bool
	reportPath       string
	startTime        time.Time
	progressChan     chan progressMsg
	repairResults    []RepairResult
	repairedCount    int
	repairAttempted  bool
	normalizeResults []NormalizeResult
	normalizedCount  int
}

type scanCompleteMsg struct{}
type repairCompleteMsg struct {
	results       []RepairResult
	repairedCount int
}
type normalizeCompleteMsg struct {
	results         []NormalizeResult
	normalizedCount int
}
type moveCompleteMsg struct{}
type folderScanCompleteMsg struct{}
type deleteCompleteMsg struct{}
type reportCompleteMsg struct{ path string }
type progressMsg struct {
	current int
	total   int
	item    string
}

// initialModel returns a new model with the given configuration.
// It initializes the spinner with a dot spinner and a foreground color of "205".
// It initializes the progress model with a default gradient.
// The returned model has its phase set to PhaseInit, and its startTime set to the current time.
// The progress channel has a capacity of 100 progress messages.
func initialModel(scanner *FileScanner, corruptionOnly, emptyFoldersOnly, dryRun, noConfirm, repair, normalizeEPUB, forceNormalize, keepBackups bool) model {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	p := progress.New(progress.WithDefaultGradient())

	return model{
		scanner:          scanner,
		phase:            PhaseInit,
		spinner:          s,
		progress:         p,
		corruptionOnly:   corruptionOnly,
		emptyFoldersOnly: emptyFoldersOnly,
		dryRun:           dryRun,
		noConfirm:        noConfirm,
		repair:           repair,
		normalizeEPUB:    normalizeEPUB,
		forceNormalize:   forceNormalize,
		keepBackups:      keepBackups,
		startTime:        time.Now(),
		progressChan:     make(chan progressMsg, 100),
	}
}

// Init initializes the model and returns a Batch command to start the scanning process.
// If emptyFoldersOnly is true, it sets the phase to PhaseScanningFolders and starts scanning for empty folders.
// If not, it sets the phase to PhaseScanning and starts scanning for corrupted files.
// The returned command also includes a spinner tick and a progress listener.
func (m model) Init() tea.Cmd {
	if m.emptyFoldersOnly {
		m.phase = PhaseScanningFolders
		m.scanner.SetProgressCallback(func(current, total int, item string) {
			select {
			case m.progressChan <- progressMsg{current: current, total: total, item: item}:
			default:
			}
		})
		return tea.Batch(
			m.spinner.Tick,
			listenForProgress(m.progressChan),
			func() tea.Msg {
				_ = m.scanner.ScanForEmptyFolders()
				return folderScanCompleteMsg{}
			},
		)
	}

	m.phase = PhaseScanning
	m.scanner.SetProgressCallback(func(current, total int, item string) {
		select {
		case m.progressChan <- progressMsg{current: current, total: total, item: item}:
		default:
		}
	})
	return tea.Batch(
		m.spinner.Tick,
		listenForProgress(m.progressChan),
		doScan(m.scanner),
	)
}

// doScan starts the scanning process for corrupted files and returns a Batch command that will return a scanCompleteMsg{} when the scanning process is complete.
func doScan(scanner *FileScanner) tea.Cmd {
	return func() tea.Msg {
		_ = scanner.ScanForCorruption()
		return scanCompleteMsg{}
	}
}

// doRepair starts the repair process for corrupted files and returns a Batch command that will return a repairCompleteMsg{} when the repair process is complete.
// The repair process will send progress updates to the given progress channel.
// The returned command also includes a spinner tick and a progress listener.
func doRepair(scanner *FileScanner, progressChan chan progressMsg) tea.Cmd {
	return func() tea.Msg {
		files := scanner.Result.CorruptedFiles
		totalFiles := len(files)
		if totalFiles == 0 {
			return repairCompleteMsg{}
		}

		workerCount := runtime.NumCPU()
		if workerCount > totalFiles {
			workerCount = totalFiles
		}
		if workerCount < 1 {
			workerCount = 1
		}

		jobs := make(chan CorruptedFile, workerCount)
		results := make([]RepairResult, 0, totalFiles)
		var resultsMu sync.Mutex
		var repairedCount atomic.Int32
		var processed atomic.Int32

		var wg sync.WaitGroup
		for i := 0; i < workerCount; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for job := range jobs {
					result := RepairFile(job.Path)
					if result.Fixed {
						repairedCount.Add(1)
					}
					resultsMu.Lock()
					results = append(results, result)
					resultsMu.Unlock()

					if progressChan != nil {
						current := int(processed.Add(1))
						select {
						case progressChan <- progressMsg{
							current: current,
							total:   totalFiles,
							item:    filepath.Base(job.Path),
						}:
						default:
						}
					}
				}
			}()
		}

		for _, corruptedFile := range files {
			jobs <- corruptedFile
		}
		close(jobs)
		wg.Wait()

		return repairCompleteMsg{
			results:       results,
			repairedCount: int(repairedCount.Load()),
		}
	}
}

// doNormalize starts the normalization process for EPUB files and returns a Batch command that will return a normalizeCompleteMsg{} when the normalization process is complete.
func doNormalize(scanner *FileScanner, progressChan chan progressMsg, keepBackups bool, forceNormalize bool) tea.Cmd {
	return func() tea.Msg {
		epubPaths := scanner.ScanForAllEPUBs()
		totalFiles := len(epubPaths)
		if totalFiles == 0 {
			return normalizeCompleteMsg{}
		}

		workerCount := runtime.NumCPU()
		if workerCount > totalFiles {
			workerCount = totalFiles
		}
		if workerCount < 1 {
			workerCount = 1
		}

		jobs := make(chan string, workerCount)
		results := make([]NormalizeResult, 0, totalFiles)
		var resultsMu sync.Mutex
		var normalizedCount atomic.Int32
		var processed atomic.Int32

		var wg sync.WaitGroup
		for i := 0; i < workerCount; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for path := range jobs {
					result := NormalizeEPUBWithDryRun(path, keepBackups, false, forceNormalize)
					if result.Modified {
						normalizedCount.Add(1)
					}
					resultsMu.Lock()
					results = append(results, result)
					resultsMu.Unlock()

					if progressChan != nil {
						current := int(processed.Add(1))
						select {
						case progressChan <- progressMsg{
							current: current,
							total:   totalFiles,
							item:    filepath.Base(path),
						}:
						default:
						}
					}
				}
			}()
		}

		for _, path := range epubPaths {
			jobs <- path
		}
		close(jobs)
		wg.Wait()

		scanner.markEPUBCacheDirty()

		return normalizeCompleteMsg{
			results:         results,
			normalizedCount: int(normalizedCount.Load()),
		}
	}
}

// listenForProgress creates a tea.Cmd that listens for progress updates on the given channel.
// When a progress update is received, it is immediately sent back to the caller.
// This can be used to forward progress updates from a subprocess to the main process.
func listenForProgress(sub chan progressMsg) tea.Cmd {
	return func() tea.Msg {
		return <-sub
	}
}

// startMoving starts the process of moving corrupted files to the corrupted directory.
// It returns a Batch command that will return a moveCompleteMsg{} when the moving process is complete.
// The returned command also includes a spinner tick and a progress listener.
func startMoving(scanner *FileScanner) tea.Cmd {
	return func() tea.Msg {
		_ = scanner.MoveCorruptedFiles()
		return moveCompleteMsg{}
	}
}

// startFolderScan starts the process of scanning for empty folders.
// It returns a Batch command that will return a folderScanCompleteMsg{} when the scanning process is complete.
// The returned command also includes a spinner tick and a progress listener.
func startFolderScan(scanner *FileScanner) tea.Cmd {
	return func() tea.Msg {
		_ = scanner.ScanForEmptyFolders()
		return folderScanCompleteMsg{}
	}
}

// startDeleting starts the process of deleting empty folders.
// It returns a Batch command that will return a deleteCompleteMsg{} when the deletion process is complete.
// The returned command also includes a spinner tick and a progress listener.
func startDeleting(scanner *FileScanner) tea.Cmd {
	return func() tea.Msg {
		_ = scanner.DeleteEmptyFolders()
		return deleteCompleteMsg{}
	}
}

// generateReport generates a Markdown report based on the scan result and returns a Batch command that will return a reportCompleteMsg{} when the generation process is complete.
// The returned command also includes a spinner tick and a progress listener.
// The report will be saved to a file named "ebook_mechanic_report_<timestamp>.md" in the given root directory.
// The timestamp is in the format "2006-01-02_15-04-05".
func generateReport(scanner *FileScanner, rootDir, corruptedDir string) tea.Cmd {
	return func() tea.Msg {
		path, _ := GenerateMarkdownReport(scanner.Result, rootDir, corruptedDir)
		return reportCompleteMsg{path: path}
	}
}

// Update is the core update function for the model. It listens for messages such as:
// - tea.KeyMsg for user input
// - progressMsg for progress updates
// - scanCompleteMsg for the completion of the file scanning phase
// - folderScanCompleteMsg for the completion of the folder scanning phase
// - moveCompleteMsg for the completion of the corrupted file moving phase
// - repairCompleteMsg for the completion of the corrupted file repair phase
// - deleteCompleteMsg for the completion of the empty folder deletion phase
// - reportCompleteMsg for the completion of the report generation phase
// - tea.Quit for the program to exit
// - spinner.TickMsg for the spinner to tick
// - progress.FrameMsg for the progress bar to update its frame
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "y", "Y":
			if m.phase == PhaseDeleting && !m.confirmed && !m.noConfirm {
				m.confirmed = true
				m.phase = PhaseDeleting
				m.scanner.SetProgressCallback(func(current, total int, item string) {
					select {
					case m.progressChan <- progressMsg{current: current, total: total, item: item}:
					default:
					}
				})
				return m, tea.Batch(
					listenForProgress(m.progressChan),
					startDeleting(m.scanner),
				)
			}
		case "n", "N":
			if m.phase == PhaseDeleting && !m.confirmed && !m.noConfirm {
				m.phase = PhaseGeneratingReport
				return m, generateReport(m.scanner, m.scanner.RootDir, m.scanner.CorruptedDir)
			}
		}

	case progressMsg:
		m.current = msg.current
		m.total = msg.total
		m.currentItem = msg.item
		return m, listenForProgress(m.progressChan)

	case scanCompleteMsg:
		m.current = 0
		m.total = 0
		m.currentItem = ""
		corruptedCount := len(m.scanner.Result.CorruptedFiles)
		if m.dryRun || corruptedCount == 0 {
			if corruptedCount == 0 {
				m.repairAttempted = false
			}
			if m.corruptionOnly {
				m.phase = PhaseGeneratingReport
				return m, generateReport(m.scanner, m.scanner.RootDir, m.scanner.CorruptedDir)
			}
			m.phase = PhaseScanningFolders
			m.scanner.SetProgressCallback(func(current, total int, item string) {
				select {
				case m.progressChan <- progressMsg{current: current, total: total, item: item}:
				default:
				}
			})
			return m, tea.Batch(
				listenForProgress(m.progressChan),
				startFolderScan(m.scanner),
			)
		}
		// If normalize-epub mode is enabled, normalize EPUB files after repair
		if m.normalizeEPUB && !m.repairAttempted {
			m.phase = PhaseNormalizing
			return m, tea.Batch(
				listenForProgress(m.progressChan),
				doNormalize(m.scanner, m.progressChan, m.keepBackups, m.forceNormalize),
			)
		}
		// If repair mode is enabled, attempt to repair corrupted files once before moving
		if m.repair && !m.repairAttempted {
			m.phase = PhaseRepairing
			return m, tea.Batch(
				listenForProgress(m.progressChan),
				doRepair(m.scanner, m.progressChan),
			)
		}
		// Either repairs are disabled, already attempted, or there was nothing to fix; move files
		m.phase = PhaseMoving
		m.scanner.SetProgressCallback(func(current, total int, item string) {
			select {
			case m.progressChan <- progressMsg{current: current, total: total, item: item}:
			default:
			}
		})
		return m, tea.Batch(
			listenForProgress(m.progressChan),
			startMoving(m.scanner),
		)

	case repairCompleteMsg:
		m.current = 0
		m.total = 0
		m.currentItem = ""
		m.repairResults = msg.results
		m.repairedCount = msg.repairedCount
		m.repairAttempted = true

		// Re-scan to update the list of corrupted files after repair
		m.phase = PhaseScanning
		m.scanner.Result = &ScanResult{
			CorruptedFiles: []CorruptedFile{},
			EmptyFolders:   []string{},
		}
		m.scanner.SetProgressCallback(func(current, total int, item string) {
			select {
			case m.progressChan <- progressMsg{current: current, total: total, item: item}:
			default:
			}
		})
		return m, tea.Batch(
			m.spinner.Tick,
			listenForProgress(m.progressChan),
			doScan(m.scanner),
		)

	case normalizeCompleteMsg:
		m.current = 0
		m.total = 0
		m.currentItem = ""
		m.normalizeResults = msg.results
		m.normalizedCount = msg.normalizedCount

		// After normalize, proceed with repair if enabled, or move to next phase
		if m.repair && !m.repairAttempted {
			m.phase = PhaseRepairing
			return m, tea.Batch(
				listenForProgress(m.progressChan),
				doRepair(m.scanner, m.progressChan),
			)
		}

		// Skip to move phase since normalization was done
		m.phase = PhaseMoving
		m.scanner.SetProgressCallback(func(current, total int, item string) {
			select {
			case m.progressChan <- progressMsg{current: current, total: total, item: item}:
			default:
			}
		})
		return m, tea.Batch(
			listenForProgress(m.progressChan),
			startMoving(m.scanner),
		)

	case moveCompleteMsg:
		m.current = 0
		m.total = 0
		m.currentItem = ""
		if m.corruptionOnly {
			m.phase = PhaseGeneratingReport
			return m, generateReport(m.scanner, m.scanner.RootDir, m.scanner.CorruptedDir)
		}
		m.phase = PhaseScanningFolders
		m.scanner.SetProgressCallback(func(current, total int, item string) {
			select {
			case m.progressChan <- progressMsg{current: current, total: total, item: item}:
			default:
			}
		})
		return m, tea.Batch(
			listenForProgress(m.progressChan),
			startFolderScan(m.scanner),
		)

	case folderScanCompleteMsg:
		m.current = 0
		m.total = 0
		m.currentItem = ""
		if m.dryRun || len(m.scanner.Result.EmptyFolders) == 0 {
			m.phase = PhaseGeneratingReport
			return m, generateReport(m.scanner, m.scanner.RootDir, m.scanner.CorruptedDir)
		}
		m.phase = PhaseDeleting
		if m.noConfirm {
			m.confirmed = true
			m.scanner.SetProgressCallback(func(current, total int, item string) {
				select {
				case m.progressChan <- progressMsg{current: current, total: total, item: item}:
				default:
				}
			})
			return m, tea.Batch(
				listenForProgress(m.progressChan),
				startDeleting(m.scanner),
			)
		}
		return m, nil

	case deleteCompleteMsg:
		m.phase = PhaseGeneratingReport
		return m, generateReport(m.scanner, m.scanner.RootDir, m.scanner.CorruptedDir)

	case reportCompleteMsg:
		m.reportPath = msg.path
		m.phase = PhaseDone
		return m, tea.Quit

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case progress.FrameMsg:
		progressModel, cmd := m.progress.Update(msg)
		m.progress = progressModel.(progress.Model)
		return m, cmd
	}

	return m, nil
}

// View returns a string representation of the current application state, including the current phase,
// progress, and any relevant statistics or errors.
func (m model) View() string {
	var s strings.Builder

	// Title
	s.WriteString(titleStyle.Render("📚 EBOOKMECHANIC"))
	s.WriteString("\n\n")

	// Current phase
	switch m.phase {
	case PhaseInit:
		s.WriteString(fmt.Sprintf("%s Initializing...\n", m.spinner.View()))

	case PhaseScanning:
		s.WriteString(headerStyle.Render("🔍 Scanning for Corrupted Ebooks"))
		s.WriteString("\n\n")
		s.WriteString(fmt.Sprintf("%s Checking: %s\n", m.spinner.View(), m.currentItem))
		s.WriteString(fmt.Sprintf("   Progress: %d/%d files\n", m.current, m.total))

	case PhaseRepairing:
		s.WriteString(headerStyle.Render("🔧 Repairing Corrupted Ebooks"))
		s.WriteString("\n\n")
		s.WriteString(fmt.Sprintf("%s Repairing: %s\n", m.spinner.View(), m.currentItem))
		s.WriteString(fmt.Sprintf("   Progress: %d/%d files\n", m.current, m.total))
		if m.repairedCount > 0 {
			s.WriteString(fmt.Sprintf("   %s Repaired so far: %d\n", successStyle.Render("✓"), m.repairedCount))
		}

	case PhaseNormalizing:
		s.WriteString(headerStyle.Render("📐 Normalizing EPUB Files"))
		s.WriteString("\n\n")
		s.WriteString(fmt.Sprintf("%s Normalizing: %s\n", m.spinner.View(), m.currentItem))
		s.WriteString(fmt.Sprintf("   Progress: %d/%d files\n", m.current, m.total))
		if m.normalizedCount > 0 {
			s.WriteString(fmt.Sprintf("   %s Normalized so far: %d\n", successStyle.Render("✓"), m.normalizedCount))
		}

	case PhaseMoving:
		s.WriteString(headerStyle.Render("📦 Moving Corrupted Files"))
		s.WriteString("\n\n")
		s.WriteString(fmt.Sprintf("%s Moving: %s\n", m.spinner.View(), m.currentItem))
		s.WriteString(fmt.Sprintf("   Progress: %d/%d files\n", m.current, m.total))

	case PhaseScanningFolders:
		s.WriteString(headerStyle.Render("📁 Scanning for Empty Folders"))
		s.WriteString("\n\n")
		s.WriteString(fmt.Sprintf("%s Checking: %s\n", m.spinner.View(), m.currentItem))
		s.WriteString(fmt.Sprintf("   Progress: %d/%d folders\n", m.current, m.total))

	case PhaseDeleting:
		if !m.confirmed && !m.noConfirm {
			s.WriteString(headerStyle.Render("🗑️  Delete Empty Folders?"))
			s.WriteString("\n\n")
			s.WriteString(fmt.Sprintf("Found %d empty folder(s)\n\n", len(m.scanner.Result.EmptyFolders)))
			s.WriteString(infoStyle.Render("Press 'y' to confirm, 'n' to skip"))
			s.WriteString("\n")
		} else {
			s.WriteString(headerStyle.Render("🗑️  Deleting Empty Folders"))
			s.WriteString("\n\n")
			s.WriteString(fmt.Sprintf("%s Deleting: %s\n", m.spinner.View(), m.currentItem))
			s.WriteString(fmt.Sprintf("   Progress: %d/%d folders\n", m.current, m.total))
		}

	case PhaseGeneratingReport:
		s.WriteString(fmt.Sprintf("%s Generating report...\n", m.spinner.View()))

	case PhaseDone:
		elapsed := time.Since(m.startTime)
		s.WriteString(successStyle.Render("✅ ALL OPERATIONS COMPLETED!"))
		s.WriteString("\n\n")

		// Statistics
		stats := m.buildStatsView()
		s.WriteString(statsStyle.Render(stats))
		s.WriteString("\n\n")

		if m.reportPath != "" {
			s.WriteString(infoStyle.Render(fmt.Sprintf("📄 Report: %s", filepath.Base(m.reportPath))))
			s.WriteString("\n")
		}

		s.WriteString(statusStyle.Render(fmt.Sprintf("\n⏱️  Completed in %s", elapsed.Round(time.Second))))
		s.WriteString("\n")
	}

	if m.err != nil {
		s.WriteString("\n")
		s.WriteString(errorStyle.Render(fmt.Sprintf("Error: %v", m.err)))
	}

	return s.String()
}

// buildStatsView generates a markdown string containing statistics about the scan result.
// It includes the total number of files scanned, the number of corrupted files, and the number of empty folders.
// If the repair option is enabled, it also includes the number of files that were successfully repaired.
// The statistics are grouped by file type (EPUB, MOBI, AZW3, AZW4, and PDF).
// A status icon (✓ or ❌) is used to indicate whether a file type has corrupted files or not.
func (m model) buildStatsView() string {
	var s strings.Builder

	result := m.scanner.Result

	s.WriteString(headerStyle.Render("📊 Statistics"))
	s.WriteString("\n\n")

	// Corruption stats
	s.WriteString(fmt.Sprintf("Files Scanned:     %d\n", result.TotalFiles))
	s.WriteString(fmt.Sprintf("Corrupted Files:   %d\n", len(result.CorruptedFiles)))

	// Repair stats
	if m.repair && len(m.repairResults) > 0 {
		s.WriteString(fmt.Sprintf("Repair Attempted:  %d\n", len(m.repairResults)))
		s.WriteString(fmt.Sprintf("Successfully Fixed: %d %s\n", m.repairedCount,
			successStyle.Render("✓")))
	}

	// Normalize stats
	if m.normalizeEPUB && len(m.normalizeResults) > 0 {
		s.WriteString(fmt.Sprintf("EPUB Normalize Attempted: %d\n", len(m.normalizeResults)))
		s.WriteString(fmt.Sprintf("Successfully Normalized: %d %s\n", m.normalizedCount,
			successStyle.Render("✓")))
	}
	s.WriteString("\n")

	// By file type
	s.WriteString("By Type:\n")
	s.WriteString(fmt.Sprintf("  EPUB: %d/%d %s\n", result.EPUBCorrupted, result.EPUBTotal, statusIcon(result.EPUBCorrupted)))
	s.WriteString(fmt.Sprintf("  MOBI: %d/%d %s\n", result.MOBICorrupted, result.MOBITotal, statusIcon(result.MOBICorrupted)))
	s.WriteString(fmt.Sprintf("  AZW3: %d/%d %s\n", result.AZW3Corrupted, result.AZW3Total, statusIcon(result.AZW3Corrupted)))
	s.WriteString(fmt.Sprintf("  AZW4: %d/%d %s\n", result.AZW4Corrupted, result.AZW4Total, statusIcon(result.AZW4Corrupted)))
	s.WriteString(fmt.Sprintf("  PDF:  %d/%d %s\n", result.PDFCorrupted, result.PDFTotal, statusIcon(result.PDFCorrupted)))
	s.WriteString("\n")

	// Folder stats
	s.WriteString(fmt.Sprintf("Folders Scanned:   %d\n", result.TotalFolders))
	s.WriteString(fmt.Sprintf("Empty Folders:     %d\n", len(result.EmptyFolders)))

	return s.String()
}

func statusIcon(corrupted int) string {
	if corrupted > 0 {
		return errorStyle.Render("❌")
	}
	return successStyle.Render("✅")
}

// main is the entry point of the program.
//
// It parses command-line flags and runs either in simple mode (without TUI)
// or with a TUI. The TUI displays a progress bar and statistics about the scan.
//
// The program supports the following flags:
//
// -dir: specify the root directory to scan
// -corrupted-dir: specify the directory for corrupted files
// -corruption-only: only check for corrupted files
// -empty-folders-only: only check for empty folders
// -dry-run: scan only, don't modify anything
// -no-confirm: skip confirmation prompts
// -no-tui: disable TUI, use simple output
// -repair: attempt to repair corrupted files before moving them
func main() {
	// Check for completion command first
	if len(os.Args) >= 2 && os.Args[1] == "completion" {
		handleCompletion(os.Args[2:])
		return
	}

	// Command-line flags
	var (
		directory        = flag.String("dir", ".", "Root directory to scan")
		corruptedDir     = flag.String("corrupted-dir", "CORRUPTED", "Directory for corrupted files")
		corruptionOnly   = flag.Bool("corruption-only", false, "Only check for corrupted files")
		emptyFoldersOnly = flag.Bool("empty-folders-only", false, "Only check for empty folders")
		dryRun           = flag.Bool("dry-run", false, "Scan only, don't modify anything")
		noConfirm        = flag.Bool("no-confirm", false, "Skip confirmation prompts")
		noTUI            = flag.Bool("no-tui", false, "Disable TUI, use simple output")
		repair           = flag.Bool("repair", false, "Attempt to repair corrupted files before moving them")
		normalizeEPUB    = flag.Bool("normalize-epub", false, "Normalize EPUB files to Sigil standards (implies -repair)")
		forceNormalize   = flag.Bool("force-normalize", false, "Force normalization even if EPUB appears already normalized")
		keepBackups      = flag.Bool("keep-backups", false, "Keep .backup files after successful operations")
		cleanBackups     = flag.Bool("clean-backups", false, "Remove existing .backup files in directory")
	)

	flag.Parse()

	// Handle cleanup of existing backups if requested
	if *cleanBackups {
		fmt.Printf("Cleaning existing backup files in %s...\n", *directory)
		if err := cleanExistingBackups(*directory); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: Failed to clean backups: %v\n", err)
		} else {
			fmt.Println("✓ Backup cleanup complete")
		}

		// Exit after cleanup if that's the only operation requested
		if !*normalizeEPUB && !*repair && !*corruptionOnly && !*emptyFoldersOnly {
			return
		}
	}

	// Resolve directory
	absDir, err := filepath.Abs(*directory)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Check if directory exists
	if _, err := os.Stat(absDir); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: Directory '%s' does not exist\n", absDir)
		os.Exit(1)
	}

	// Create scanner
	scanner := NewFileScanner(absDir, *corruptedDir)

	if *noTUI {
		// Run in simple mode without TUI
		runSimpleMode(scanner, *corruptionOnly, *emptyFoldersOnly, *dryRun, *noConfirm, *repair, *normalizeEPUB, *keepBackups, *forceNormalize)
		return
	}

	// Run with TUI
	m := initialModel(scanner, *corruptionOnly, *emptyFoldersOnly, *dryRun, *noConfirm, *repair, *normalizeEPUB, *forceNormalize, *keepBackups)
	p := tea.NewProgram(m)

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runSimpleMode(scanner *FileScanner, corruptionOnly, emptyFoldersOnly, dryRun, noConfirm, repair, normalizeEPUB, keepBackups, forceNormalize bool) {
	fmt.Println("========================================")
	fmt.Println("EBOOKMECHANIC")
	fmt.Println("========================================")
	fmt.Printf("Directory: %s\n", scanner.RootDir)
	fmt.Printf("Corrupted files destination: %s\n\n", scanner.CorruptedDir)

	startTime := time.Now()
	repairedCount := 0
	normalizedCount := 0

	// Corruption scan
	if !emptyFoldersOnly {
		fmt.Println("Scanning for corrupted files...")
		_ = scanner.ScanForCorruption()
		fmt.Printf("Found %d corrupted file(s)\n\n", len(scanner.Result.CorruptedFiles))

		// Normalize EPUB files if normalize mode is enabled
		if normalizeEPUB {
			// Find ALL EPUB files for normalization (not just corrupted ones)
			epubPaths := scanner.ScanForAllEPUBs()
			epubFiles := []CorruptedFile{}
			for _, path := range epubPaths {
				epubFiles = append(epubFiles, CorruptedFile{
					Path:   path,
					Reason: "Selected for normalization",
				})
			}

			if len(epubFiles) > 0 {
				fmt.Println("Normalizing EPUB files to Sigil standards...")
				for i, epubFile := range epubFiles {
					fmt.Printf("  [%d/%d] %s: %s\n", i+1, len(epubFiles),
						func() string {
							if dryRun {
								return "Would normalize"
							}
							return "Normalizing"
						}(),
						filepath.Base(epubFile.Path))
					result := NormalizeEPUBWithDryRun(epubFile.Path, keepBackups, dryRun, forceNormalize)
					switch {
					case result.Modified:
						normalizedCount++
						status := "✓ Normalized"
						if dryRun {
							status = "✓ Would normalize"
						}
						fmt.Printf("    %s: %s (%d changes)\n", status, result.Message, result.ChangesCount)
						for _, detail := range result.Details {
							fmt.Printf("      - %s\n", detail)
						}
					case result.Success:
						fmt.Printf("    ○ %s\n", result.Message)
					default:
						fmt.Printf("    ✗ Failed: %s\n", result.Message)
					}
				}
				fmt.Printf("Successfully normalized: %d/%d EPUB files\n\n", normalizedCount, len(epubFiles))
			}
		}

		// Repair corrupted files if repair mode is enabled
		if repair && !dryRun && len(scanner.Result.CorruptedFiles) > 0 {
			fmt.Println("Attempting to repair corrupted files...")
			for i, corruptedFile := range scanner.Result.CorruptedFiles {
				fmt.Printf("  [%d/%d] Repairing: %s\n", i+1, len(scanner.Result.CorruptedFiles),
					filepath.Base(corruptedFile.Path))
				result := RepairFile(corruptedFile.Path)
				switch {
				case result.Fixed:
					repairedCount++
					fmt.Printf("    ✓ Fixed: %s\n", result.Message)
				case result.Success:
					fmt.Printf("    ○ %s\n", result.Message)
				default:
					fmt.Printf("    ✗ Failed: %s\n", result.Message)
				}
			}
			fmt.Printf("Successfully repaired: %d/%d files\n\n", repairedCount, len(scanner.Result.CorruptedFiles))

			// Re-scan to update corrupted files list
			fmt.Println("Re-scanning to verify repairs...")
			scanner.Result = &ScanResult{
				CorruptedFiles: []CorruptedFile{},
				EmptyFolders:   []string{},
			}
			_ = scanner.ScanForCorruption()
			fmt.Printf("Remaining corrupted files: %d\n\n", len(scanner.Result.CorruptedFiles))
		}

		if !dryRun && len(scanner.Result.CorruptedFiles) > 0 {
			fmt.Println("Moving corrupted files...")
			_ = scanner.MoveCorruptedFiles()
			fmt.Println("Done")
		}
	}

	// Empty folder scan
	if !corruptionOnly {
		fmt.Println("Scanning for empty folders...")
		_ = scanner.ScanForEmptyFolders()
		fmt.Printf("Found %d empty folder(s)\n\n", len(scanner.Result.EmptyFolders))

		if !dryRun && len(scanner.Result.EmptyFolders) > 0 {
			if !noConfirm {
				fmt.Print("Delete empty folders? (y/n): ")
				var response string
				_, _ = fmt.Scanln(&response)
				if response != "y" && response != "Y" {
					fmt.Println("Skipped")
					goto report
				}
			}
			fmt.Println("Deleting empty folders...")
			_ = scanner.DeleteEmptyFolders()
			fmt.Println("Done")
		}
	}

report:
	// Generate report
	fmt.Println("Generating report...")
	reportPath, _ := GenerateMarkdownReport(scanner.Result, scanner.RootDir, scanner.CorruptedDir)

	elapsed := time.Since(startTime)

	fmt.Println("========================================")
	fmt.Println("SUMMARY")
	fmt.Println("========================================")
	fmt.Printf("Files scanned:     %d\n", scanner.Result.TotalFiles)
	fmt.Printf("Corrupted files:   %d\n", len(scanner.Result.CorruptedFiles))
	if normalizeEPUB && normalizedCount > 0 {
		fmt.Printf("EPUB normalized:   %d\n", normalizedCount)
	}
	if repair && repairedCount > 0 {
		fmt.Printf("Files repaired:    %d\n", repairedCount)
	}
	fmt.Printf("Folders scanned:   %d\n", scanner.Result.TotalFolders)
	fmt.Printf("Empty folders:     %d\n", len(scanner.Result.EmptyFolders))
	fmt.Printf("Report: %s\n", reportPath)
	fmt.Printf("Completed in: %s\n", elapsed.Round(time.Second))
}

// bashCompletion returns the bash completion script
func bashCompletion() string {
	return `# ebook-mechanic bash completion
_ebook_mechanic() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="-dir -corrupted-dir -corruption-only -empty-folders-only -dry-run -no-confirm -no-tui -repair -normalize-epub -force-normalize -keep-backups -clean-backups"

    case "${prev}" in
        -dir|-corrupted-dir)
            COMPREPLY=( $(compgen -d -- "${cur}") )
            return 0
            ;;
    esac

    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
}

complete -F _ebook_mechanic ebook-mechanic
`
}

// zshCompletion returns the zsh completion script
func zshCompletion() string {
	return `#compdef ebook-mechanic

_ebook_mechanic() {
    local context state state_descr line
    typeset -A opt_args

    _arguments \
        '-dir[Root directory to scan]:directory:_directories' \
        '-corrupted-dir[Directory for corrupted files]:directory:_directories' \
        '-corruption-only[Only check for corrupted files]' \
        '-empty-folders-only[Only check for empty folders]' \
        '-dry-run[Scan only, do not modify anything]' \
        '-no-confirm[Skip confirmation prompts]' \
        '-no-tui[Disable TUI, use simple output]' \
        '-repair[Attempt to repair corrupted files before moving them]' \
        '-normalize-epub[Normalize EPUB files to Sigil standards (implies -repair)]' \
        '-force-normalize[Force normalization even if EPUB appears already normalized]' \
        '-keep-backups[Keep .backup files after successful operations]' \
        '-clean-backups[Remove existing .backup files in directory]'
}

_ebook_mechanic "$@"
`
}

// fishCompletion returns the fish completion script
func fishCompletion() string {
	return `# ebook-mechanic fish completion
complete -c ebook-mechanic -s h -l help -d 'Show help'
complete -c ebook-mechanic -o dir -d 'Root directory to scan' -r -F
complete -c ebook-mechanic -o corrupted-dir -d 'Directory for corrupted files' -r -F
complete -c ebook-mechanic -o corruption-only -d 'Only check for corrupted files'
complete -c ebook-mechanic -o empty-folders-only -d 'Only check for empty folders'
complete -c ebook-mechanic -o dry-run -d 'Scan only, do not modify anything'
complete -c ebook-mechanic -o no-confirm -d 'Skip confirmation prompts'
complete -c ebook-mechanic -o no-tui -d 'Disable TUI, use simple output'
complete -c ebook-mechanic -o repair -d 'Attempt to repair corrupted files before moving them'
complete -c ebook-mechanic -o normalize-epub -d 'Normalize EPUB files to Sigil standards (implies -repair)'
complete -c ebook-mechanic -o force-normalize -d 'Force normalization even if EPUB appears already normalized'
complete -c ebook-mechanic -o keep-backups -d 'Keep .backup files after successful operations'
complete -c ebook-mechanic -o clean-backups -d 'Remove existing .backup files in directory'

# Completion subcommand
complete -c ebook-mechanic -n '__fish_use_subcommand' -a completion -d 'Generate shell completion scripts'
complete -c ebook-mechanic -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish powershell' -d 'Shell type'
`
}

// powershellCompletion returns the PowerShell completion script
func powershellCompletion() string {
	return `# ebook-mechanic PowerShell completion
Register-ArgumentCompleter -CommandName ebook-mechanic -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)

    $flags = @(
        '-dir',
        '-corrupted-dir',
        '-corruption-only',
        '-empty-folders-only',
        '-dry-run',
        '-no-confirm',
        '-no-tui',
        '-repair',
        '-normalize-epub',
        '-force-normalize',
        '-keep-backups',
        '-clean-backups'
    )

    $flags | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
    }
}
`
}
