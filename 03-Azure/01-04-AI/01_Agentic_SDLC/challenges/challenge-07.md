# Challenge 7 - Implement agentic workflows to maintain the app

**[Home](../Readme.md)** - [Previous Challenge](challenge-06.md) - [Next Challenge](finish.md)

## Goal

Implement **GitHub Agentic Workflows** to help maintain the Octocat Supply application over time. Delivering the app is only the beginning — the team needs sustainable, agent-driven maintenance: triaging issues, keeping dependencies current, and responding to changes in the repository.

## Actions

* **Identify maintenance tasks** — Choose a recurring task that benefits from automation (e.g. issue triage/labelling, dependency updates, test/lint on change, documentation upkeep). Start with a **low-risk** task.
* **Author an agentic workflow** — Create a GitHub Agentic Workflow that performs one of these tasks autonomously.
* **Define triggers and guardrails** — Configure when it runs (schedule, PR, issue) and constrain what it is allowed to do — least privilege.
* **Test the workflow** — Trigger it and observe the agent completing the task.
* **Review the output** — Confirm the agent's actions are correct and safe before enabling it broadly.

## Success criteria

* At least one agentic workflow is implemented and completes a real run.
* The workflow has clear triggers and appropriate, least-privilege guardrails.
* The agent completes a real maintenance task on the repository (not a no-op).
* The workflow's output is reviewed for correctness and safety.

### Optional stretch — package a reusable skill / slash command

* Pick a repeatable flow you've done by hand (e.g. "read instructions → scaffold tests → run validation").
* Package it as a reusable **skill or slash command** so it can be invoked in one step.
* Invoke it against a real task and confirm it performs the steps.
* Document where **human review stays mandatory** (e.g. before merging generated tests or committing changes).

## Learning resources

* [GitHub Agentic Workflows (gh-aw)](https://github.com/githubnext/gh-aw)
* [About GitHub Actions](https://docs.github.com/en/actions/learn-github-actions)
* [Controlling permissions for GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
