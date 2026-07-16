# Challenge 2 - Add another feature from the backlog (agentic loop)

**[Home](../Readme.md)** - [Previous Challenge](challenge-01.md) - [Next Challenge](challenge-03.md)

## Goal

Pick up an additional feature from the Octocat Supply backlog and deliver it with a fuller **agentic loop** — plan → implement → test → review. With the cart underway, the team needs to keep burning down the backlog before launch.

## Actions

* **Choose a backlog item** — Pick a meaningful feature from `assets/backlog.md` (e.g. payment integration for the cart, order history, product search/filtering, or inventory management). A set of these may already be seeded as **GitHub Issues** in your repo — check the Issues tab and pick one.
* **Plan with an agent** — Use GitHub Copilot to break the work into steps and identify the files and layers involved (frontend, API, database) **before** writing code.
* **Implement** — Build the feature across the stack, keeping changes consistent with existing patterns and type-safe.
* **Add tests** — Cover the new logic with unit tests (API/repository) and component tests where relevant.
* **Review** — Use Copilot to review your own change before considering it done.

## Success criteria

* A new, working backlog feature is delivered end to end and demonstrable in the running app.
* The feature has appropriate automated test coverage.
* Code follows existing repository conventions and is type-safe.
* You used an agentic plan → implement → test → review loop and can point to the agent's plan, the implementation, the tests, and the review pass.

### Optional stretch — harnesses, MCP & requirement refinement

* **Compare harnesses** — Run the planning step twice: once in **Copilot CLI** and once in the **Copilot App / IDE chat**. Note which gave the more implementation-ready plan for a quick fix vs. a multi-file change, and write down a decision rule.
* **Wire in an MCP server** — Connect one MCP server (e.g. the **GitHub MCP server**) to pull real backlog context such as issues and PRs. Note what stays local-only vs. what the server can see.
* **Refine a requirement from organizational signal** — Point your agent at `assets/workiq/` — the mock **WorkIQ** organizational knowledge (Teams thread, support-ticket digest, stakeholder email). Have it synthesize the signal across those artifacts, separate a genuinely-new need from noise and from work **already in the backlog**, and shape one unmet need into an **issue-ready requirement**: problem statement → acceptance criteria → scoped tasks (optionally opening it as a GitHub Issue). There's no answer key — the skill is the refinement. A ready-made **Requirement Refiner** custom agent (`.github/agents/`) can guide this.

## Learning resources

* [About GitHub Copilot coding agent](https://docs.github.com/en/copilot/using-github-copilot/coding-agent)
* [Extending Copilot Chat with the Model Context Protocol (MCP)](https://docs.github.com/en/copilot/customizing-copilot/extending-copilot-chat-with-mcp)
* [GitHub MCP server](https://github.com/github/github-mcp-server)
