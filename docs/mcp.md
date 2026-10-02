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

## Check the server and its data

1. Open Runic and refresh usage. In **Settings → Sync → Integrations → Runic MCP**, click **Check data**. It reports the snapshot age, enabled provider count, and which providers have quota, credit, balance, or extra-usage values. An empty optional package list does not affect the built-in server.
2. Install the CLI from **Settings → Performance → Refresh & Safety → Install CLI**, or use `/Applications/Runic.app/Contents/Helpers/RunicCLI` in place of `runic` below.
3. Run these local checks:

   ```bash
   runic mcp list
   runic mcp call runic_health
   runic mcp call runic_limits
   runic mcp call runic_limits '{"provider":"claude"}'
   ```

`mcp list` lists the two built-in tools and any valid, enabled package tools. `mcp call` invokes the same tool handler used by the stdio server and prints its JSON result; it exits with an error for a missing snapshot, unknown/disabled tool, or failed package. The `provider` argument is optional and must be a Runic provider ID shown by `runic_limits`. For a full client check, paste **Copy client config** into your AI client's MCP configuration, restart or reconnect that client, and ask it to list Runic tools and call `runic_health`. If the snapshot is missing or stale, refresh Runic first; the MCP process itself does not refresh providers.

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

For a minimal local test, save this as `tool.sh` next to the manifest and run `chmod +x tool.sh`:

```sh
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"message":"hello from the example package"}'
```

Put the containing `example` folder in `mcpservers`, then run `runic mcp list` and `runic mcp call example_hello`. The package should also appear in Settings within a few seconds. This sample ignores its input and returns fixed data; a real package should parse the JSON request and validate arguments.

Packages are executable code with the same local user access as Runic. Install only packages you trust. They are registered by path, so updating the files in that folder updates the package without rebuilding Runic. This initial package API adds MCP tools; it does not add new usage providers or modify Runic's refresh scheduler.
