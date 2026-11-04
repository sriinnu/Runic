import Foundation
import Testing
@testable import RunicCore

/// macOS 27 denies a Developer ID app without a provisioning profile any `group.`
/// container, with no prompt. The entitlements and the code must also name the
/// same group, or the widget and the app read different folders.
struct WidgetAppGroupTests {
    @Test
    func `the group is team prefixed in code and in the packaged entitlements`() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(
            contentsOf: root.appendingPathComponent("Scripts/package_app.sh"),
            encoding: .utf8)
        #expect(WidgetSnapshotStore.appGroupID.hasPrefix("RSH5FK4MB6."))
        #expect(script.contains("APP_GROUP_ID=\"\(WidgetSnapshotStore.appGroupID)\""))
        #expect(script.contains("APP_GROUP_ID=\"\(WidgetSnapshotStore.appGroupID).debug\""))
        #expect(!script.contains("group.com.sriinnu"))
    }
}
