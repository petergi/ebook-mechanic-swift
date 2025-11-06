import SwiftUI
import EbookMechanicCore

struct ContentView: View {
    @ObservedObject var viewModel: ScanViewModel
    @Binding var selectedDirectory: URL
    @Binding var options: ScanOptions
    var onSelectDirectory: () -> Void
    var onRunScan: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.indigo.opacity(0.25), Color.gray.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header
                controls
                progressSection
                results
                Spacer()
            }
            .padding(32)
        }
        .onChange(of: options.emptyFoldersOnly) { newValue in
            if newValue { options.corruptionOnly = false }
        }
        .onChange(of: options.corruptionOnly) { newValue in
            if newValue { options.emptyFoldersOnly = false }
        }
        .onChange(of: options.dryRun) { newValue in
            if newValue {
                options.autoMoveCorrupted = false
                options.autoDeleteEmptyFolders = false
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EbookMechanic")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("Lightning-fast ebook maintenance with a beautiful native interface")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label(selectedDirectory.path, systemImage: "folder")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Choose…", action: onSelectDirectory)
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isScanning)
            }

            HStack(spacing: 16) {
                Toggle("Attempt repair", isOn: $options.repair)
                    .disabled(viewModel.isScanning)
                Toggle("Dry run", isOn: $options.dryRun)
                    .disabled(viewModel.isScanning)
                Toggle("Generate report", isOn: $options.generateReport)
                    .disabled(viewModel.isScanning)
            }

            HStack(spacing: 16) {
                Toggle("Corruption only", isOn: $options.corruptionOnly)
                    .disabled(viewModel.isScanning)
                Toggle("Empty folders only", isOn: $options.emptyFoldersOnly)
                    .disabled(viewModel.isScanning)
                Toggle("Auto move corrupted", isOn: $options.autoMoveCorrupted)
                    .disabled(viewModel.isScanning || options.dryRun)
                Toggle("Auto delete empty", isOn: $options.autoDeleteEmptyFolders)
                    .disabled(viewModel.isScanning || options.dryRun)
            }

            HStack(spacing: 12) {
                TextField("Corrupted folder name", text: $options.corruptedDirectoryName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .disabled(viewModel.isScanning)

                Spacer()

                Button {
                    onRunScan()
                } label: {
                    Label(viewModel.isScanning ? "Working…" : "Run Scan", systemImage: viewModel.isScanning ? "hourglass" : "play.fill")
                        .frame(minWidth: 160)
                }
                .disabled(viewModel.isScanning)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var progressSection: some View {
        Group {
            if viewModel.isScanning {
                HStack {
                    ProgressView()
                    VStack(alignment: .leading) {
                        Text(viewModel.progressHeadline.isEmpty ? "Processing" : viewModel.progressHeadline)
                            .font(.headline)
                        if !viewModel.progressDetail.isEmpty {
                            Text(viewModel.progressDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var results: some View {
        HStack(alignment: .top, spacing: 24) {
            summaryCard
            corruptedList
            emptyFolderList
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Summary", systemImage: "chart.bar.doc.horizontal")
                .font(.headline)
            if let summary = viewModel.summary {
                Text("Files scanned: \(summary.totalFiles)")
                Text("Corrupted: \(summary.corruptedFiles.count)")
                Divider()
                ForEach(EbookFileType.allCases, id: \.self) { type in
                    let breakdown = summary.breakdown(for: type)
                    let status = breakdown.corrupted > 0 ? "❌" : "✅"
                    Text("\(status) \(type.fileExtension.dropFirst().uppercased()): \(breakdown.corrupted)/\(breakdown.total)")
                        .font(.caption)
                }
            } else {
                Text("Run a scan to see results")
                    .foregroundStyle(.secondary)
            }

            if let reportURL = viewModel.reportURL {
                Divider()
                Label("Report saved to \(reportURL.lastPathComponent)", systemImage: "doc.text")
                    .font(.caption)
            }

            if !viewModel.statusMessages.isEmpty {
                Divider()
                ForEach(viewModel.statusMessages, id: \.self) { message in
                    Text(message)
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: 260, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var corruptedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Corrupted Files", systemImage: "exclamationmark.triangle")
                .font(.headline)
            if viewModel.corruptedFiles.isEmpty {
                Text("None detected")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.corruptedFiles, id: \.url) { file in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.url.lastPathComponent)
                                    .fontWeight(.semibold)
                                Text(file.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyFolderList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Empty Folders", systemImage: "trash")
                .font(.headline)
            if viewModel.emptyFolders.isEmpty {
                Text("None detected")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.emptyFolders, id: \.self) { folder in
                            Text(folder.path)
                                .font(.caption)
                                .padding(10)
                                .background(Color.yellow.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
