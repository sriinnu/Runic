import AppKit
import SwiftUI

@MainActor
struct HelpPane: View {
    var body: some View {
        PreferencesPane {
            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Menu refresh")
                    .font(RunicFont.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("Use Ping now in the menu to update usage without closing the panel.")
                    .font(RunicFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Auto-refresh cadence and safety rules live in Performance > Refresh & Safety.")
                    .font(RunicFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Manual mode avoids background refreshes that may touch tokens.")
                    .font(RunicFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Data sources")
                    .font(RunicFont.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("Runic reads local logs or browser cookies depending on provider settings.")
                    .font(RunicFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Open Providers to review each source and add credentials.")
                    .font(RunicFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
