#!/usr/bin/env python3
"""Render the Challenge 1 Azure-resources diagram.

Draws every Azure resource, the LLM model fleet, and the surrounding
identity / delivery plane that Challenge 1 provisions (via ``azd up`` or
``labautomation/deploy.sh``) for the Contract Lifecycle Management microhack.

Outputs:
    images/challenge-01/challenge-0-azure-resources.png
    images/challenge-01/challenge-0-azure-resources.svg

Usage:
    python src/scripts/make_challenge0_resources.py
"""
from __future__ import annotations

import pathlib

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

# --------------------------------------------------------------------------
# Fonts — prefer Segoe UI on Windows, fall back to the default sans stack.
# --------------------------------------------------------------------------
for _f in (
    r"C:\Windows\Fonts\segoeui.ttf",
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\seguisb.ttf",
):
    try:
        fm.fontManager.addfont(_f)
    except Exception:  # noqa: BLE001 - font is optional
        pass
try:
    plt.rcParams["font.family"] = "Segoe UI"
except Exception:  # noqa: BLE001
    pass

# --------------------------------------------------------------------------
# Palette
# --------------------------------------------------------------------------
INK = "#1B1A19"
MUTED = "#5A5A66"
AZURE = "#0F6CBD"
RG_FILL = "#EDF4FB"
RG_EDGE = "#7AA9DD"
PANEL_FILL = "#FFFFFF"
CARD_FILL = "#F7FAFD"

FOUNDRY = "#8661C5"   # AI Foundry / Cognitive Services purple
GPT = "#0E9C6E"       # OpenAI green
ACCENT = "#CC6B3E"    # warm clay accent (client / Teams chat)
SEARCH = "#0F6CBD"    # Azure blue
SHAREPOINT = "#038387" # SharePoint teal
SQL = "#C0392B"       # SQL red
INSIGHTS = "#8E44AD"  # monitor purple
LOGS = "#0F6CBD"
IDENTITY = "#2E7D32"  # Entra green
DELIVERY = "#5B5FC7"  # M365 / Teams indigo

fig, ax = plt.subplots(figsize=(16, 11.4), dpi=150)
ax.set_xlim(0, 160)
ax.set_ylim(0, 114)
ax.set_aspect("equal")
ax.axis("off")


# --------------------------------------------------------------------------
# Drawing helpers
# --------------------------------------------------------------------------
def panel(x, y, w, h, *, fill, edge, lw=1.6, radius=1.6, dashed=False, z=1):
    ls = (0, (5, 3)) if dashed else "solid"
    ax.add_patch(
        FancyBboxPatch(
            (x, y), w, h,
            boxstyle=f"round,pad=0,rounding_size={radius}",
            linewidth=lw, edgecolor=edge, facecolor=fill,
            linestyle=ls, zorder=z, mutation_aspect=1,
        )
    )


def chip(x, y, w, h, label, color, *, fs=10, tc="white"):
    ax.add_patch(
        FancyBboxPatch(
            (x, y), w, h,
            boxstyle="round,pad=0,rounding_size=0.9",
            linewidth=0, facecolor=color, zorder=4,
        )
    )
    ax.text(x + w / 2, y + h / 2, label, ha="center", va="center",
            color=tc, fontsize=fs, fontweight="bold", zorder=5)


def text(x, y, s, *, fs=10, color=INK, weight="normal", ha="left", va="center"):
    ax.text(x, y, s, fontsize=fs, color=color, fontweight=weight,
            ha=ha, va=va, zorder=6)


def resource(x, y, w, h, mono, mono_color, title, sub, *, mono_fs=9, title_fs=11):
    """A resource card: icon chip on the left + title/subtitle."""
    panel(x, y, w, h, fill=CARD_FILL, edge="#D9E2EC", lw=1.2, radius=1.1, z=3)
    ax.add_patch(
        FancyBboxPatch(
            (x + 0.6, y + 0.6), 1.0, h - 1.2,
            boxstyle="round,pad=0,rounding_size=0.5",
            linewidth=0, facecolor=mono_color, zorder=4,
        )
    )
    chip(x + 2.2, y + h / 2 - 3.0, 9.5, 6.0, mono, mono_color, fs=mono_fs)
    tx = x + 13.5
    multiline = "\n" in sub
    if multiline:
        ty = y + h - 3.0
        ax.text(tx, ty, title, fontsize=title_fs, color=INK, fontweight="bold",
                ha="left", va="center", zorder=6)
        ax.text(tx, ty - 2.7, sub, fontsize=8.3, color=MUTED,
                ha="left", va="top", zorder=6, linespacing=1.3)
    else:
        ax.text(tx, y + h * 0.63, title, fontsize=title_fs, color=INK,
                fontweight="bold", ha="left", va="center", zorder=6)
        ax.text(tx, y + h * 0.28, sub, fontsize=8.3, color=MUTED,
                ha="left", va="center", zorder=6)


def arrow(p0, p1, *, color=MUTED, lw=2.0, dashed=False, double=False, rad=0.0):
    style = "<|-|>" if double else "-|>"
    ls = (0, (5, 3)) if dashed else "solid"
    ax.add_patch(
        FancyArrowPatch(
            p0, p1, arrowstyle=style, mutation_scale=16,
            linewidth=lw, color=color, linestyle=ls,
            shrinkA=2, shrinkB=2,
            connectionstyle=f"arc3,rad={rad}", zorder=2,
        )
    )


# --------------------------------------------------------------------------
# Title
# --------------------------------------------------------------------------
text(80, 111, "Agentic CLM Microhack — Azure Resources & Model Fleet",
     fs=21, weight="bold", ha="center")
text(80, 106.4,
     "Provisioned by  azd up  or  labautomation/deploy.sh  into a single resource group "
     "(default region: swedencentral)",
     fs=11, color=MUTED, ha="center")

# --------------------------------------------------------------------------
# User pill (client)
# --------------------------------------------------------------------------
panel(48, 99.4, 64, 5.0, fill="#FDF3E7", edge=ACCENT, lw=1.6, radius=2.2, z=3)
text(80, 101.9, "Contract Manager   ·   Microsoft 365 Copilot  &  Teams",
     fs=11.5, weight="bold", ha="center", color="#7A3E1D")

# --------------------------------------------------------------------------
# Resource group container
# --------------------------------------------------------------------------
panel(4, 5, 152, 92, fill=RG_FILL, edge=RG_EDGE, lw=2.0, radius=2.2, dashed=True, z=1)
panel(6.5, 92.6, 66, 4.4, fill="#DCEBFA", edge=RG_EDGE, lw=1.2, radius=1.4, z=2)
text(8.6, 94.8, "Resource group   ·   rg-clm-microhack   ·   swedencentral",
     fs=10.5, weight="bold", color=AZURE)

# --------------------------------------------------------------------------
# BAND A — Microsoft Foundry + model fleet
# --------------------------------------------------------------------------
panel(8, 62, 144, 29, fill=PANEL_FILL, edge=FOUNDRY, lw=2.0, radius=1.8, z=2)
chip(10, 86.8, 9.5, 3.4, "AIS", FOUNDRY, fs=9)
text(21, 88.5, "Microsoft Foundry  —  Azure AI Services account (S0)",
     fs=13, weight="bold", color=FOUNDRY)
text(21, 84.9, "project: clm-project   ·   one identity, billing, tracing & governance plane",
     fs=9.2, color=MUTED)

text(10, 81.4, "Model fleet — LLM deployments", fs=9.5, weight="bold", color=INK)

# four model cards
resource(10, 66.2, 33.5, 13.6, "GPT", GPT, "gpt-5.4",
         "OpenAI · GlobalStd 30\nOrchestrator", mono_fs=8, title_fs=9.5)
resource(46, 66.2, 33.5, 13.6, "GPT", GPT, "gpt-5.4",
         "OpenAI · shared w/ orch.\nIntake & Drafting", mono_fs=8, title_fs=9.5)
resource(82, 66.2, 33.5, 13.6, "SOL", GPT, "gpt-5.6-sol",
         "OpenAI · GlobalStd 20\nClause & Risk", mono_fs=8, title_fs=9.5)
resource(118, 66.2, 33.5, 13.6, "GPT", GPT, "gpt-5.4-nano",
         "OpenAI · GlobalStd 30\nObligation & Renewal", mono_fs=8, title_fs=9.5)

# capability tags
tags = ["Microsoft Agent Framework", "Foundry IQ (agentic retrieval)",
        "Evaluations", "Content Safety"]
tx = 11
for t in tags:
    w = 2.3 + 1.02 * len(t)
    panel(tx, 62.9, w, 2.6, fill="#F0EAF9", edge=FOUNDRY, lw=1.0, radius=1.0, z=3)
    text(tx + w / 2, 64.2, t, fs=8.2, color=FOUNDRY, weight="bold", ha="center")
    tx += w + 2.4

# --------------------------------------------------------------------------
# BAND B — grounding/data  +  observability
# --------------------------------------------------------------------------
# Left: grounding & data stores
panel(8, 30, 71, 28, fill=PANEL_FILL, edge=SEARCH, lw=1.8, radius=1.8, z=2)
text(10.5, 54.8, "Grounding & data stores", fs=12.5, weight="bold", color=SEARCH)
resource(10.5, 46.4, 66, 6.6, "SRCH", SEARCH, "Azure AI Search (Basic)",
         "clm-corpus index · clm-search connection · Foundry IQ", mono_fs=8)
resource(10.5, 38.4, 66, 6.6, "SPO", SHAREPOINT, "SharePoint document library (BYO)",
         "source contract corpus — crawled by the AI Search indexer", mono_fs=8)
resource(10.5, 30.6, 66, 6.6, "SQL", SQL, "Azure SQL Database (Basic · optional)",
         "contract status & renewals — DEPLOY_SQL / --with-sql", mono_fs=8)

# Right: observability & governance
panel(83, 30, 69, 28, fill=PANEL_FILL, edge=INSIGHTS, lw=1.8, radius=1.8, z=2)
text(85.5, 54.8, "Observability & governance", fs=12.5, weight="bold", color=INSIGHTS)
resource(85.5, 46.4, 64, 6.6, "APPI", INSIGHTS, "Application Insights",
         "OpenTelemetry traces from every agent run", mono_fs=8)
resource(85.5, 38.4, 64, 6.6, "LOGS", LOGS, "Log Analytics workspace",
         "backing store for App Insights (30-day retention)", mono_fs=8)
resource(85.5, 30.6, 64, 6.6, "EVAL", "#B8860B", "Evaluations · quality gate",
         "scorecards · Content Safety · GenAIOps (C2 / C5)", mono_fs=8)

# --------------------------------------------------------------------------
# BAND C — identity  +  delivery
# --------------------------------------------------------------------------
panel(8, 8, 71, 19, fill=PANEL_FILL, edge=IDENTITY, lw=1.8, radius=1.8, z=2)
text(10.5, 23.8, "Identity & access — Microsoft Entra ID", fs=12, weight="bold", color=IDENTITY)
text(10.5, 20.0, "System-assigned managed identities (Foundry + Search)",
     fs=9.2, color=INK)
text(10.5, 16.6, "RBAC: Azure AI Developer · Cognitive Services User",
     fs=9.2, color=MUTED)
text(10.5, 13.4, "Search Index Data roles · SharePoint indexer app registration",
     fs=9.2, color=MUTED)
text(10.5, 10.2, "Keyless, AAD data-plane auth (DefaultAzureCredential)",
     fs=9.2, color=MUTED)

panel(83, 8, 69, 19, fill=PANEL_FILL, edge=DELIVERY, lw=1.8, radius=1.8, z=2)
text(85.5, 23.8, "Delivery & clients", fs=12, weight="bold", color=DELIVERY)
resource(85.5, 16.2, 64, 6.2, "MCP", DELIVERY, "MCP server",
         "draft_contract · analyze_contract tools", mono_fs=8)
resource(85.5, 8.8, 64, 6.2, "M365", "#3B57B0", "Microsoft 365 Copilot & Teams",
         "published agent + proactive renewal alerts", mono_fs=7.5)

# --------------------------------------------------------------------------
# Connectors
# --------------------------------------------------------------------------
arrow((80, 99.2), (80, 91.2), color=ACCENT, lw=2.2, double=True)
text(82.0, 95.4, "chat", fs=8.6, color="#7A3E1D", weight="bold")

arrow((40, 61.9), (40, 58.1), color=SEARCH, lw=2.0)
text(41.2, 60.0, "ground + tools", fs=8.2, color=SEARCH, weight="bold")

arrow((118, 61.9), (118, 58.1), color=INSIGHTS, lw=2.0, dashed=True)
text(119.2, 60.0, "traces", fs=8.2, color=INSIGHTS, weight="bold")

# left rail: identity secures the plane
arrow((6.2, 27.2), (6.2, 61.8), color=IDENTITY, lw=1.6, dashed=True)
ax.text(4.9, 44.5, "identity / RBAC", fontsize=8, color=IDENTITY, weight="bold",
        rotation=90, ha="center", va="center", zorder=6)

# right rail: publish up from delivery into Foundry
arrow((153.8, 27.2), (153.8, 61.8), color=DELIVERY, lw=1.6, dashed=True)
ax.text(155.1, 44.5, "publish · MCP / Teams", fontsize=8, color=DELIVERY,
        weight="bold", rotation=90, ha="center", va="center", zorder=6)

# legend (model + client colours)
lx = 96
panel(lx, 92.8, 54, 4.0, fill="#FFFFFF", edge="#D9E2EC", lw=1.0, radius=1.2, z=2)
chip(lx + 2, 93.6, 5.5, 2.4, "", GPT, fs=1)
text(lx + 8.2, 94.8, "OpenAI (GPT)", fs=8.6, color=INK)
chip(lx + 24, 93.6, 5.5, 2.4, "", ACCENT, fs=1)
text(lx + 30.2, 94.8, "Client · Teams chat", fs=8.6, color=INK)

# --------------------------------------------------------------------------
# Save
# --------------------------------------------------------------------------
out_dir = pathlib.Path(__file__).resolve().parents[2] / "images" / "challenge-01"
out_dir.mkdir(parents=True, exist_ok=True)
png = out_dir / "challenge-0-azure-resources.png"
svg = out_dir / "challenge-0-azure-resources.svg"
fig.savefig(png, bbox_inches="tight", pad_inches=0.15, facecolor="white")
fig.savefig(svg, bbox_inches="tight", pad_inches=0.15, facecolor="white")
print(f"wrote {png}")
print(f"wrote {svg}")
