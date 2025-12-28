import EbookMechanicCore
import SwiftUI

struct InstallToolsView: View {
  @Environment(\.dismiss) var dismiss
  @State private var epubcheckInstalled: Bool = false
  @State private var pdfcpuInstalled: Bool = false

  var allToolsInstalled: Bool {
    epubcheckInstalled && pdfcpuInstalled
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        Text("External Tools Status")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text(
          "Some advanced validation and repair features require external command-line tools. "
            + "Please install them to enable full functionality."
        )
        .font(.body)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

        toolStatusRow(
          name: "EpubCheck", isInstalled: epubcheckInstalled,
          installCommand: "brew install epubcheck")
        toolStatusRow(
          name: "PDFCPU", isInstalled: pdfcpuInstalled, installCommand: "brew install pdfcpu")

        Spacer()

        Button {
          checkToolInstallation()
        } label: {
          Label("Check Again", systemImage: "arrow.clockwise")
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .disabled(allToolsInstalled)
      }
      .padding(.vertical)
      .onAppear(perform: checkToolInstallation)
      .navigationTitle("Install External Tools")
      .toolbar {
        ToolbarItem(placement: .navigation) {  // Use .navigation for macOS
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }

  @ViewBuilder
  private func toolStatusRow(name: String, isInstalled: Bool, installCommand: String) -> some View {
    HStack {
      Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundColor(isInstalled ? .green : .red)
      Text(name)
      Spacer()
      if !isInstalled {
        Button("Copy Command") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(installCommand, forType: .string)
        }
        .buttonStyle(.bordered)
      }
    }
    .padding(.horizontal)
  }

  private func checkToolInstallation() {
    Task {
      epubcheckInstalled = await isCommandAvailable("epubcheck")
      pdfcpuInstalled = await isCommandAvailable("pdfcpu")
    }
  }

  private func isCommandAvailable(_ command: String) async -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-l", "-c", "which \(command)"]  // -l ensures .bash_profile/.zshrc are sourced

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
      let status = process.terminationStatus
      return status == 0
    } catch {
      print("Error checking command \(command): \(error.localizedDescription)")
      return false
    }
  }
}

// #Preview {
//     InstallToolsView()
// }
