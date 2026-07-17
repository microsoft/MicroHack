# Challenge 4 - Run and extend test coverage, and review code

**[Home](../Readme.md)** - [Previous Challenge](challenge-03.md) - [Next Challenge](challenge-05.md)

## Goal

Bring the testing and review of the application up to Octocat standards by running the existing tests, extending coverage, and performing an agent-assisted code review. The mindset shift is from "does it work?" to "can I trust it?".

## Actions

* **Run the existing tests** — Execute the current API and frontend test suites and confirm the baseline passes.
* **Find the gaps** — Use Copilot to identify untested code paths, especially around the new cart and backlog features.
* **Extend coverage** — Add unit tests for repository/business logic and component tests for critical UI paths. Include edge cases and error handling.
* **Review the code** — Use Copilot (and/or the code review agent) to review recent changes for correctness, security, and data integrity.
* **Fix what you find** — Address issues surfaced by the tests and review, prioritising security and correctness over style.

## Success criteria

* Existing test suites run green.
* New tests meaningfully increase coverage of the recent features and exercise edge cases and error handling.
* A code review has been performed and actionable findings addressed.

> Repo rule: only run linters, builds, and tests that **already exist** in the repo — no new test frameworks mid-hack.

### Optional stretch — model selection & context budgeting

* **Compare models** — Generate tests for the same code once in **Auto** mode and once with an **explicitly selected model**. Compare and record a decision rule for when to use each.
* **Set a context budget** — Before prompting, decide a budget (max number of files, max reference length per file) and stick to it.
* **Note the trade-off** — Capture how the budget affected quality vs. noise in the generated tests.

## Learning resources

* [Configuring GitHub Copilot code review](https://docs.github.com/en/copilot/using-github-copilot/code-review/using-copilot-code-review)
* [Writing tests with GitHub Copilot](https://docs.github.com/en/copilot/using-github-copilot/guides-on-using-github-copilot/writing-tests-with-github-copilot)
* [Changing the AI model for Copilot Chat](https://docs.github.com/en/copilot/using-github-copilot/ai-models/changing-the-ai-model-for-copilot-chat)
