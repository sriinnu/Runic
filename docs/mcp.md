# Runic MCP

Runic includes one local MCP server with two built-in tools. An AI client starts the bundled `RunicCLI` over stdio when it needs a tool; Runic does not open a network port. The server reads the latest account-free usage snapshot written by the Runic app. Open Runic and refresh usage once before calling a built-in tool.

In **Preferences → Sync → Integrations → Runic MCP**, choose **Copy client config**. The configuration has this shape (adjust the app path if you installed Runic elsewhere):

```json
{
  "mcpServers": {
    "runic": {
      "command": "/Applications/Runic.app/Contents/Helpers/RunicCLI",
      "args": ["mcp", "serve"]
    }
  }
}
```

Use the `runic` entry in your client's MCP configuration. Some clients use a different outer key; keep the command and args. Restart the client after changing the configuration or Runic's plugin list.

The built-in read-only tools are:

- `runic_limits`: current provider quota windows, reset times, credits remaining, balance, and extra usage where the provider supplies them. Optional `provider` argument filters by Runic provider ID. Missing fields mean Runic has no verified value; it never invents a credit total.
- `runic_health`: last refresh, snapshot age, provider data age, source labels, and safe error flags. A stale flag means data is older than three refresh intervals (at least 15 minutes). It does not probe provider credentials or make a network request.

Runic only exports enabled providers. The snapshot does not contain account email, organization, tokens, cookies, or raw provider error text. The local snapshot and plugin registry are stored under `~/Library/Application Support/Runic/` with user-only file permissions.

## Local tool packages

Runic automatically discovers tool packages in direct child folders of `~/Library/Application Support/Runic/mcpservers/`. Open **Preferences → Sync → Integrations → Runic MCP → Open mcpservers** to create and reveal the folder. Drop a package folder there; Runic lists it in Settings within a few seconds, and `runic mcp list` lists it too. A connected MCP client may need to reconnect to refresh its tool list. Removing the folder stops discovery; switching its Enabled control off keeps the files in place and saves that choice.

You can also load a package from another trusted local folder with **Add folder** or `runic mcp add /path/to/folder`. `runic mcp enable <id>`, `disable <id>`, and `remove <id>` manage these registrations. Removing a registered package leaves its files in place. A package inside `mcpservers` cannot be removed through the registry; move its folder instead.

A package contains `runic-mcp-plugin.json` and an executable within the same folder. For example:

```json
{
  "apiVersion": 1,
  "id": "example",
  "name": "Example tools",
  "version": "1.0.0",
  "executable": "tool.sh",
  "tools": [
    {
      "name": "hello",
      "description": "Return a greeting",
      "inputSchema": {
        "type": "object",
        "properties": { "name": { "type": "string" } }
      }
    }
  ]
}
```

This exposes `example_hello`. Runic starts the executable once per tool call, with the package folder as its working directory. It sends one JSON object on stdin: `{"tool":"hello","arguments":{"name":"Sriinnu"}}`. The executable must write one valid JSON value to stdout and exit successfully. Stderr is ignored by the MCP host; stdout is capped at 64 KiB. Tool names are prefixed by the package ID to avoid collisions. A package can declare multiple tools served by one executable.

Packages are executable code with the same local user access as Runic. Install only packages you trust. They are registered by path, so updating the files in that folder updates the package without rebuilding Runic. This initial package API adds MCP tools; it does not add new usage providers or modify Runic's refresh scheduler.
