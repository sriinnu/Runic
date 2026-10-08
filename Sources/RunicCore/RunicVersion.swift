/// The marketing version Runic reports from places that have no Info.plist:
/// the CLI's `--version` and the MCP server handshake. Keep in step with
/// `version.env`; `Scripts/release.sh` and a test both refuse drift.
public enum RunicVersion {
    public static let marketing = "2.10.0"
}
