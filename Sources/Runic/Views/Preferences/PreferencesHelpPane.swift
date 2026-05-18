import AppKit
import SwiftUI

@MainActor
struct HelpPane: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        PreferencesPane {
            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Menu refresh")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .textCase(.uppercase)

                Text("Use Ping now in the menu to update usage without closing the panel.")
                    .font(self.fonts.body)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Auto-refresh cadence and safety rules live in Performance > Refresh & Safety.")
                    .font(self.fonts.body)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Manual mode avoids background refreshes that may touch tokens.")
                    .font(self.fonts.body)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Data sources")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .textCase(.uppercase)

                Text("Runic reads local logs or browser cookies depending on provider settings.")
                    .font(self.fonts.body)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Open Providers to review each source and add credentials.")
                    .font(self.fonts.body)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
