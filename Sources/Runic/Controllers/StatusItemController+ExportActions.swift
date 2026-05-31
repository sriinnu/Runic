import AppKit
import RunicCore
import UniformTypeIdentifiers

extension StatusItemController {
    @objc func exportUsageCSV(_ sender: NSMenuItem) {
        self.exportUsage(format: .csv)
    }

    @objc func exportUsageJSON(_ sender: NSMenuItem) {
        self.exportUsage(format: .json)
    }

    func exportUsage(format: UsageExporter.Format, scope: UsageExporter.Scope = .all) {
        let provider = self.lastMenuProvider
            ?? (self.store.isEnabled(.codex) ? .codex : self.store.enabledProviders().first)
            ?? .codex
        let content = UsageExporter.export(store: self.store, provider: provider, format: format, scope: scope)

        let panel = NSSavePanel()
        panel.title = "Export \(scope.displayName)"
        panel.nameFieldStringValue = "runic-\(provider.rawValue)-\(scope.fileSuffix).\(format.rawValue)"
        panel.allowedContentTypes = format == .csv
            ? [.commaSeparatedText]
            : [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
