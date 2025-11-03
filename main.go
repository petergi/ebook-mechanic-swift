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
	confirmed        bool
	reportPath       string
	startTime        time.Time
	progressChan     chan progressMsg
}

type scanCompleteMsg struct{}
type moveCompleteMsg struct{}
type folderScanCompleteMsg struct{}
type deleteCompleteMsg struct{}
type reportCompleteMsg struct{ path string }
type progressMsg struct {
	current int
	total   int
	item    string
}

func initialModel(scanner *FileScanner, corruptionOnly, emptyFoldersOnly, dryRun, noConfirm bool) model {
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
		startTime:        time.Now(),
		progressChan:     make(chan progressMsg, 100),
	}
}

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

func doScan(scanner *FileScanner) tea.Cmd {
	return func() tea.Msg {
		_ = scanner.ScanForCorruption()
		return scanCompleteMsg{}
	}
}

func listenForProgress(sub chan progressMsg) tea.Cmd {
	return func() tea.Msg {
		return <-sub
	}
}

func startMoving(scanner *FileScanner) tea.Cmd {
	return func() tea.Msg {
		_ = scanner.MoveCorruptedFiles()
		return moveCompleteMsg{}
	}
}

func startFolderScan(scanner *FileScanner) tea.Cmd {
	return func() tea.Msg {
		_ = scanner.ScanForEmptyFolders()
		return folderScanCompleteMsg{}
	}
}

func startDeleting(scanner *FileScanner) tea.Cmd {
	return func() tea.Msg {
		_ = scanner.DeleteEmptyFolders()
		return deleteCompleteMsg{}
	}
}

func generateReport(scanner *FileScanner, rootDir, corruptedDir string) tea.Cmd {
	return func() tea.Msg {
		path, _ := GenerateMarkdownReport(scanner.Result, rootDir, corruptedDir)
		return reportCompleteMsg{path: path}
	}
}

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
		if m.dryRun || len(m.scanner.Result.CorruptedFiles) == 0 {
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

func (m model) buildStatsView() string {
	var s strings.Builder

	result := m.scanner.Result

	s.WriteString(headerStyle.Render("📊 Statistics"))
	s.WriteString("\n\n")

	// Corruption stats
	s.WriteString(fmt.Sprintf("Files Scanned:     %d\n", result.TotalFiles))
	s.WriteString(fmt.Sprintf("Corrupted Files:   %d\n", len(result.CorruptedFiles)))
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
		runSimpleMode(scanner, *corruptionOnly, *emptyFoldersOnly, *dryRun, *noConfirm)
		return
	}

	// Run with TUI
	m := initialModel(scanner, *corruptionOnly, *emptyFoldersOnly, *dryRun, *noConfirm)
	p := tea.NewProgram(m)

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runSimpleMode(scanner *FileScanner, corruptionOnly, emptyFoldersOnly, dryRun, noConfirm bool) {
	fmt.Println("========================================")
	fmt.Println("EBOOKMECHANIC")
	fmt.Println("========================================")
	fmt.Printf("Directory: %s\n", scanner.RootDir)
	fmt.Printf("Corrupted files destination: %s\n\n", scanner.CorruptedDir)

	startTime := time.Now()

	// Corruption scan
	if !emptyFoldersOnly {
		fmt.Println("Scanning for corrupted files...")
		_ = scanner.ScanForCorruption()
		fmt.Printf("Found %d corrupted file(s)\n\n", len(scanner.Result.CorruptedFiles))

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
	fmt.Printf("Folders scanned:   %d\n", scanner.Result.TotalFolders)
	fmt.Printf("Empty folders:     %d\n", len(scanner.Result.EmptyFolders))
	fmt.Printf("\nReport: %s\n", reportPath)
	fmt.Printf("Completed in: %s\n", elapsed.Round(time.Second))
}
