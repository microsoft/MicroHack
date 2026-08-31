# Challenge 1 - Dev environment, Copilot access & repo overview

**[Home](../Readme.md)** - [Next Challenge](challenge-02.md)

> **⚠️ Important — before you start.** Log into GitHub using the **hackathon-provided GitHub account** (labuser-0000_msXXXXXX — not your personal or corporate account), then **fork the MicroHack repo** in the MngEnvMCAPXXXXXX organization by setting that account as the **owner** of the fork. All later challenges — commits, pull requests, Actions runs, and OIDC federation — assume you're working from that fork under the hackathon account.
>
> When you create your Codespace, the repo offers **many** dev container configurations (one per MicroHack track). Do **not** create a Codespace with default settings. Select **"New with options..."**, then be sure to select **"Azure / AI / Agentic SDLC"** from the configuration picker — picking the wrong one (or the default) leaves you without the tools this track needs.

## Goal

Configure your development environment, confirm GitHub Copilot access, and get familiar with the **Octocat Supply** application so the later challenges run without setup interruptions.

The Octocat team is behind schedule and adopting Agentic Development practices. Before you can help deliver features, you need a working environment, Copilot enabled, and a clear picture of the codebase.

## Actions

* **Get the code** — Open your team's copy of this MicroHack in **GitHub Codespaces** (recommended), a local **VS Code Dev Container** (`.devcontainer/`), or locally. Confirm you're on the intended working branch.
* **Verify runtimes** — Confirm the runtimes for your chosen API track are available (TypeScript, Python, .NET, or Java) plus Node.js for the frontend. In Codespaces / the Dev Container these are preinstalled.
* **Enable GitHub Copilot** — Sign in and confirm your Copilot entitlement is active in your IDE; install the GitHub Copilot / Copilot Chat extensions.
* **Explore the repo** — Review the structure: `src/` (the app, with `src/docs/` architecture guidance), `infra/` + `scripts/` (Azure deployment), `assets/` (Challenge 3 backlog & WorkIQ inputs), and `.github/` (Copilot custom instructions & agents). Identify where the frontend, APIs, and database live. Read `src/README.md` for the code structure and build commands.
* **Run the app locally** — Start the frontend and one API to confirm the application builds and runs before you begin changing it.

## Success criteria

* Your team's repo copy is open in your environment and Copilot is active and responding in your IDE.
* You can build and run the frontend and at least one API locally.
* You can describe, at a high level, how the frontend, APIs, and database fit together.

### Optional stretch — repo-wide agent context

Give Copilot persistent, repo-wide context so later challenges start with your conventions loaded.

* Create an `AGENTS.md` and/or `.github/copilot-instructions.md` recording coding conventions, naming, and preferred patterns.
* Record the exact **build and test commands** for your API track (and the frontend) so an agent can verify its own work.
* Add explicit **scope rules** (e.g. don't touch generated files, infra, unrelated services) to keep agent diffs minimal.
* In a fresh Copilot Chat, ask a question that relies on those conventions **without restating them** and confirm they're applied.

## Learning resources

* [Setting up GitHub Copilot](https://docs.github.com/en/copilot/quickstart)
* [GitHub Codespaces](https://docs.github.com/en/codespaces/overview)
* [Development Containers](https://containers.dev/)
* [Adding repository custom instructions for Copilot](https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot)
