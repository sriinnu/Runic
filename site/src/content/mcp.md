---
title: "Runic MCP"
---

# Runic MCP

Runic ships a local [MCP](https://modelcontextprotocol.io) server so an AI client (Claude Code, Codex, Cursor, or anything that speaks MCP) can ask about your quota and credits. The client starts `RunicCLI mcp serve` over stdio when it needs a tool. Runic opens no network port, and the server reads the latest snapshot written by the Runic app, so open Runic and refresh usage once before the first call.

## Connect a client

In **Settings → Sync → Integrations → Runic MCP**, choose **Copy client config**. It looks like this (adjust the path if Runic lives somewhere other than `/Applications`):

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

Paste the `runic` entry into your client's MCP configuration (some clients use a different outer key; keep `command` and `args`), then restart or reconnect the client and ask it to list Runic tools.

## Built-in tools

Both tools are read-only.

| Tool | Returns |
| --- | --- |
| `runic_limits` | Current quota windows, reset times, credits remaining, balance and extra usage for every enabled provider. Optional `provider` argument filters to one Runic provider ID. A missing field means Runic has no verified value; it never invents a number. |
| `runic_health` | Last refresh time, snapshot age, per-provider data age, source labels (`oauth`, `api`, `cli`, …) and safe error flags. `stale` means data is older than three refresh intervals (at least 15 minutes). Makes no network request and never probes credentials. |

The snapshot carries only enabled providers and no account email, organization, tokens, cookies or raw provider error text. It lives under `~/Library/Application Support/Runic/` with user-only permissions.

## Test it locally

```
runic mcp list                               # built-in tools + enabled packages
runic mcp call runic_health
runic mcp call runic_limits
runic mcp call runic_limits '{"provider":"claude"}'
```

`mcp call` runs the same handler the stdio server uses and prints its JSON. It errors on a missing snapshot, an unknown or disabled tool, or a failed package. If data looks stale, refresh Runic; the MCP process does not refresh providers itself.

In Settings, **Values available to MCP clients** shows exactly what the snapshot exposes, and **Check data** reloads the preview with snapshot age and provider coverage.

## CLI subcommands

```
runic mcp serve                 Start the MCP server for an AI client
runic mcp list                  List built-in and installed capabilities
runic mcp call <tool> [json]    Test a tool and print its local data
runic mcp add <folder>          Register a local plugin package
runic mcp remove <id|path>      Unregister a plugin without deleting its files
runic mcp enable|disable <id>   Toggle an installed plugin
```

## Local tool packages

You can add your own tools without rebuilding Runic. Runic discovers packages in direct child folders of `~/Library/Application Support/Runic/mcpservers/` (**Settings → Sync → Integrations → Runic MCP → Open mcpservers**) within a few seconds, or you can register a folder elsewhere with **Add folder** / `runic mcp add <path>`. A connected client may need to reconnect to see new tools.

A package is a folder with `runic-mcp-plugin.json` and an executable:

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

This exposes `example_hello` (tool names are prefixed with the package ID). Per call, Runic starts the executable with the package folder as working directory, writes one JSON object to stdin — `{"tool":"hello","arguments":{"name":"Ada"}}` — and expects one JSON value on stdout and a zero exit. Stdout is capped at 64 KiB; stderr is ignored. One executable can serve several tools.

Minimal `tool.sh` (`chmod +x` it):

```sh
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"message":"hello from the example package"}'
```

Drop the `example` folder into `mcpservers`, then `runic mcp list` and `runic mcp call example_hello`.

Packages run as you, with your local access. Install only ones you trust. They are registered by path, so editing the files updates the package in place. The package API adds MCP tools; it does not add usage providers or change Runic's refresh scheduler.
