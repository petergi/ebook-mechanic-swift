package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
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

// Phase represents different stages of the application
type Phase int

const (
	PhaseInit Phase = iota
	PhaseScanning
	PhaseRepairing
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
	confirmed        bool
	reportPath       string
	startTime        time.Time
	progressChan     chan progressMsg
	repairResults    []RepairResult
	repairedCount    int
	repairAttempted  bool
}

type scanCompleteMsg struct{}
type repairCompleteMsg struct {
	results       []RepairResult
	repairedCount int
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
func initialModel(scanner *FileScanner, corruptionOnly, emptyFoldersOnly, dryRun, noConfirm, repair bool) model {
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
		results := []RepairResult{}
		repairedCount := 0
		totalFiles := len(scanner.Result.CorruptedFiles)

		for i, corruptedFile := range scanner.Result.CorruptedFiles {
			// Send progress update
			select {
			case progressChan <- progressMsg{
				current: i + 1,
				total:   totalFiles,
				item:    filepath.Base(corruptedFile.Path),
			}:
			default:
			}

			// Attempt repair
			result := RepairFile(corruptedFile.Path)
			results = append(results, result)
			if result.Fixed {
				repairedCount++
			}
		}

		return repairCompleteMsg{
			results:       results,
			repairedCount: repairedCount,
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
	)

	flag.Parse()

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
		runSimpleMode(scanner, *corruptionOnly, *emptyFoldersOnly, *dryRun, *noConfirm, *repair)
		return
	}

	// Run with TUI
	m := initialModel(scanner, *corruptionOnly, *emptyFoldersOnly, *dryRun, *noConfirm, *repair)
	p := tea.NewProgram(m)

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runSimpleMode(scanner *FileScanner, corruptionOnly, emptyFoldersOnly, dryRun, noConfirm, repair bool) {
	fmt.Println("========================================")
	fmt.Println("EBOOKMECHANIC")
	fmt.Println("========================================")
	fmt.Printf("Directory: %s\n", scanner.RootDir)
	fmt.Printf("Corrupted files destination: %s\n\n", scanner.CorruptedDir)

	startTime := time.Now()
	repairedCount := 0

	// Corruption scan
	if !emptyFoldersOnly {
		fmt.Println("Scanning for corrupted files...")
		_ = scanner.ScanForCorruption()
		fmt.Printf("Found %d corrupted file(s)\n\n", len(scanner.Result.CorruptedFiles))

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

	fmt.Println("\n========================================")
	fmt.Println("SUMMARY")
	fmt.Println("========================================")
	fmt.Printf("Files scanned:     %d\n", scanner.Result.TotalFiles)
	fmt.Printf("Corrupted files:   %d\n", len(scanner.Result.CorruptedFiles))
	if repair && repairedCount > 0 {
		fmt.Printf("Files repaired:    %d\n", repairedCount)
	}
	fmt.Printf("Folders scanned:   %d\n", scanner.Result.TotalFolders)
	fmt.Printf("Empty folders:     %d\n", len(scanner.Result.EmptyFolders))
	fmt.Printf("\nReport: %s\n", reportPath)
	fmt.Printf("Completed in: %s\n", elapsed.Round(time.Second))
}
