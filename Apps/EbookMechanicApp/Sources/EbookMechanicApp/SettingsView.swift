import EbookMechanicCore
import SwiftUI

struct SettingsView: View {
  @AppStorage("defaultReportFormats") private var defaultReportFormatsData: Data = Data()
  @AppStorage("defaultConcurrencyLevel") private var defaultConcurrencyLevel: Int = ProcessInfo
    .processInfo.activeProcessorCount
  @AppStorage("enableExternalToolsByDefault") private var enableExternalToolsByDefault: Bool = false
  @AppStorage("showPerformanceStatsByDefault") private var showPerformanceStatsByDefault: Bool =
    false

  @State private var selectedDefaultFormats: Set<ReportFormat> = []

  var body: some View {
    Form {
      Section("General Settings") {
        Toggle("Enable External Tools by Default", isOn: $enableExternalToolsByDefault)
        Toggle("Show Performance Statistics by Default", isOn: $showPerformanceStatsByDefault)

        Stepper(
          "Default Concurrency Level: \(defaultConcurrencyLevel)", value: $defaultConcurrencyLevel,
          in: 1...16)
      }

      Section("Default Report Formats") {
        ForEach(ReportFormat.allCases, id: \.self) { format in
          Toggle(
            format.rawValue.capitalized,
            isOn: Binding(
              get: { selectedDefaultFormats.contains(format) },
              set: {
                if $0 {
                  selectedDefaultFormats.insert(format)
                } else {
                  selectedDefaultFormats.remove(format)
                }
              }
            ))
        }
      }
    }
    .padding()
    .frame(width: 400, height: 300)
    .onAppear(perform: loadDefaultFormats)
    .onDisappear(perform: saveDefaultFormats)
  }

  private func loadDefaultFormats() {
    if let decoded = try? JSONDecoder().decode(
      Set<ReportFormat>.self, from: defaultReportFormatsData)
    {
      selectedDefaultFormats = decoded
    }
  }

  private func saveDefaultFormats() {
    if let encoded = try? JSONEncoder().encode(selectedDefaultFormats) {
      defaultReportFormatsData = encoded
    }
  }
}

// #Preview {
//     SettingsView()
// }
