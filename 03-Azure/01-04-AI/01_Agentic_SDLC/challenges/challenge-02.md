# Challenge 2 - Deliver a new feature (the cart)

**[Home](../Readme.md)** - [Previous Challenge](challenge-01.md) - [Next Challenge](challenge-03.md)

## Goal

Deliver a new feature for the Octocat Supply application by completing the incomplete shopping **cart** functionality, using GitHub Copilot to move fast while keeping the code consistent with the existing app.

The shopping cart is incomplete and lacks payment integration, which is blocking the launch. The focus of this challenge is **using Copilot well** — giving it the right context and iterating — not just writing code.

## Actions

* **Understand the current state** — Review the existing cart-related code in the frontend and API. Use Copilot to explain what exists and what's missing.
* **Design the feature** — Decide the cart behaviours to implement: add item, update quantity, remove item, view cart total.
* **Implement the API** — Add or complete the cart endpoints following the repository's patterns (repository pattern, DTOs/types, error handling, consistent HTTP status codes).
* **Implement the UI** — Wire up the frontend cart view to the API using the React + Vite + Tailwind stack.
* **Validate** — Manually exercise the cart flow end to end in the running app.

## Success criteria

* A user can add products to the cart, update quantities, and remove items.
* The cart displays an accurate total.
* Cart state is persisted through the API using existing patterns (not just client-side React state).
* Changes are type-safe and consistent with the existing codebase style, with a scoped diff.

### Optional stretch — structured prompting & context retrieval

* Build a **reusable prompt template** with clear sections: objective, constraints, files in scope, desired output format.
* Set a **context-retrieval order**: directly edited files first → adjacent tests → architecture docs only if still needed. Stop once it's enough.
* Run the cart prompt structured, then run the same request with a loose, unstructured prompt and keep the better result — the comparison is the learning.

## Learning resources

* [Prompt engineering for GitHub Copilot](https://docs.github.com/en/copilot/using-github-copilot/prompt-engineering-for-github-copilot)
* [Best practices for using GitHub Copilot](https://docs.github.com/en/copilot/using-github-copilot/best-practices-for-using-github-copilot)
* [Getting started with Copilot Chat](https://docs.github.com/en/copilot/github-copilot-chat/using-github-copilot-chat)
