import RunicCore
import SwiftUI

extension PerformanceDashboardView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Performance Dashboard")
                .font(self.fonts.title2)
                .fontWeight(.bold)

            HStack(spacing: RunicSpacing.sm) {
                self.timeRangePicker
                self.providerPicker
                if self.selection.provider != nil {
                    self.modelPicker
                }
            }
        }
    }

    var timeRangePicker: some View {
        Picker("Time Range", selection: self.$selection.timeRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
    }

    var providerPicker: some View {
        Picker("Provider", selection: self.$selection.provider) {
            Text("All Providers").tag(nil as UsageProvider?)
            ForEach(UsageProvider.allCases, id: \.self) { provider in
                Text(provider.rawValue).tag(provider as UsageProvider?)
            }
        }
        .frame(width: 140)
    }

    var modelPicker: some View {
        Picker("Model", selection: self.$selection.model) {
            Text("All Models").tag(nil as String?)
            ForEach(self.availableModels, id: \.self) { model in
                Text(model).tag(model as String?)
            }
        }
        .frame(width: 140)
    }

    var availableModels: [String] {
        let models = self.stats.compactMap(\.model).filter { !$0.isEmpty }
        return Array(Set(models)).sorted()
    }
}
