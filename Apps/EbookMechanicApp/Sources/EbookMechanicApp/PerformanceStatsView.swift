import Charts
import EbookMechanicCore
import SwiftUI

struct PerformanceStatsView: View {
  @ObservedObject var viewModel: ScanViewModel
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if let metrics = viewModel.performanceMetrics {
            Section("Overview") {
              InfoRow(
                label: "Total Validation Time",
                value: String(format: "%.2f s", metrics.totalValidationTime))
              InfoRow(
                label: "Files Per Second", value: String(format: "%.2f", metrics.filesPerSecond))
              InfoRow(
                label: "Average Time Per File",
                value: String(format: "%.3f s", metrics.averageValidationTimePerFile))
              InfoRow(
                label: "Cache Hit Rate",
                value: String(format: "%.1f %%", metrics.cacheHitRate * 100))
              InfoRow(label: "External Tool Calls", value: "\(metrics.externalToolCallCount)")
            }
            .padding(.bottom)

            if !metrics.validationTimeByFormat.isEmpty {
              Section("Average Validation Time by Format") {
                Chart(
                  metrics.validationTimeByFormat.sorted(by: { $0.key.rawValue < $1.key.rawValue }),
                  id: \.key
                ) { format, time in
                  BarMark(
                    x: .value("Format", format.rawValue.capitalized),
                    y: .value("Time (s)", time)
                  )
                  .foregroundStyle(by: .value("Format", format.rawValue.capitalized))
                }
                .chartYAxisLabel("Time (s)")
                .frame(height: 200)
              }
              .padding(.bottom)
            }

            Section("Parallel Efficiency") {
              Gauge(value: metrics.parallelEfficiencyRatio, in: 0...1) {
                Text("Efficiency")
              } currentValueLabel: {
                Text(String(format: "%.1f%%", metrics.parallelEfficiencyRatio * 100))
              }
              .gaugeStyle(.accessoryCircular)
              .tint(.teal)
              .scaleEffect(0.8)
              .frame(maxWidth: .infinity, alignment: .center)
              Text(
                "A ratio closer to 1.0 indicates better utilization of parallel processing "
                  + "capabilities. A value above 1.0 may indicate overhead from "
                  + "parallelization for very fast tasks."
              )
              .font(.caption)
              .foregroundColor(.secondary)
            }
          } else {
            Text(
              "No performance metrics available. Run a scan with "
                + "'Show Performance Stats' enabled."
            )
            .foregroundColor(.secondary)
          }
        }
        .padding()
      }
      .navigationTitle("Performance Statistics")
      .toolbar {
        ToolbarItem(placement: .navigation) {  // Use .navigation for macOS
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

// #Preview {
//     let vm = ScanViewModel()
//     vm.performanceMetrics = PerformanceMetrics(
//         filesPerSecond: 12.34,
//         totalValidationTime: 10.5,
//         averageValidationTimePerFile: 0.081,
//         externalToolCallCount: 50,
//         cacheHitRate: 0.75,
//         parallelEfficiencyRatio: 0.85,
//         validationTimeByFormat: [.epub: 0.05, .pdf: 0.1, .mobi: 0.02]
//     )
//     return PerformanceStatsView(viewModel: vm)
// }
