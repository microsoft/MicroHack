# Teams app manifest (template)

Sideload package for publishing the CLM Orchestrator to Teams / M365 Copilot when you use the
**manifest** path (the portal **Publish → Teams and Microsoft 365 Copilot** path usually generates
this for you — use this template only if you sideload manually).

## Contents
- `manifest.json` — Teams app manifest (v1.19). `${{MICROSOFT_APP_ID}}` is replaced with your Azure
  Bot's App (client) ID.
- `color.png` (192×192) and `outline.png` (32×32, transparent) — **branded placeholder icons are
  included**. Regenerate them with `python src/scripts/make_icons.py`, or drop in your own before zipping.

## Build the app package
1. Replace `${{MICROSOFT_APP_ID}}` in `manifest.json` with your Bot's App ID (or let the toolkit do
   it).
2. *(Optional)* swap the included `color.png` / `outline.png` for your own branding.
3. Zip the three files (flat, no folder):
   ```bash
   cd src/manifest && zip ../clm-assistant.zip manifest.json color.png outline.png
   ```
4. In Teams: **Apps → Manage your apps → Upload an app → Upload a custom app** → pick the zip.

> Prefer the portal's **Publish** button when available — it provisions the Azure Bot Service channel
> and wires the manifest automatically.
