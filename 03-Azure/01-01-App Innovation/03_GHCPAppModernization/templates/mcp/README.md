# MCP configuration templates

Two templates for the two MCP-capable clients used in this MicroHack. **The formats are not interchangeable** — Copilot CLI does not read `.vscode/mcp.json` (it uses the unsupported top-level key `servers`), and VS Code's documented locations are `.vscode/mcp.json` and user settings, not the Copilot CLI files.

| Template | Client | Copy to | Verify with |
|---|---|---|---|
| [copilot-cli-mcp.json](copilot-cli-mcp.json) | **GitHub Copilot CLI** (used in this hack) | `<target-repo>/.github/mcp.json` | `/mcp list` inside `copilot` |
| [mcp.json](mcp.json) | VS Code | `<target-repo>/.vscode/mcp.json` | **MCP: List Servers** in the Command Palette |

## copilot-cli-mcp.json (GitHub Copilot CLI)

- Top-level key is `mcpServers`; each server is `type: "local"` (stdio command) or `type: "http"` (remote URL). `tools` is an allow-list — `["*"]` enables all tools from that server.
- The **GitHub MCP server is built into Copilot CLI** — do not add an entry for it.
- The `azure` server uses your `az login` context; optionally pin a subscription by adding `"AZURE_SUBSCRIPTION_ID": "<id>"` to `env`. Never commit secrets — this file is meant to be committed to the repo.
- Configuration levels (highest precedence first):
  1. `.mcp.json` — local, per-checkout (not committed),
  2. `.github/mcp.json` — shared project config, committed to the repo,
  3. `~/.copilot/mcp-config.json` — your personal servers; manage with `/mcp add` (interactive form) or `copilot mcp add <name> -- <command>`.
- Project-level servers are loaded only after you confirm **folder trust** on first launch of `copilot` in the repo.
- Reference MCP tools in an agent's `tools:` list as `<server>/<tool>` or `<server>/*` (for example `azure/*`).

## mcp.json (VS Code)

- VS Code JSONC format: top-level `servers` key, `type: "stdio"` or `"http"`, plus `inputs` for prompted values.
- The `appmod-*` tool families are **not** MCP servers you configure — they are registered automatically by the GitHub Copilot app modernization VS Code extensions. Install the extension for your stack (.NET or Java).
- After editing, run **MCP: List Servers** and start/inspect the servers.

Docs: [Add MCP servers to Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers) · [MCP servers in VS Code](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)
