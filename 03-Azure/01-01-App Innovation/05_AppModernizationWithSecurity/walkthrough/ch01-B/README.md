# ch01-B solution: Rewrite from a specification

There are multiple ways to solve this challenge; below is one possible approach. This one
does not upgrade the legacy application — it **replaces** it.

The idea is spec-driven development. Instead of asking Copilot to change code, you ask it
to first work out *what the application does and why*, write that down as a Product
Requirements Document, and only then build. The document is the thing you review. If the
PRD is right, the code that follows is right; if the PRD is vague, you find out early and
cheaply.

Work in your own clone. The legacy source in `dotnet/` or `java/` is now **reference
material** — it is the most accurate description of the business logic that exists, but
you are not going to keep it.

## Step 0: Pick your target stack

You are free here. The Azure architecture is fixed (container on Azure Container Apps,
managed database, images in Azure storage), but the framework is yours to choose.

Reasonable options:

| Target | Why |
| --- | --- |
| **Node.js + TypeScript** (Express, Fastify, or Next.js) | Fastest to generate and review, huge ecosystem, great fit for a catalog UI |
| **Python + FastAPI** | Small, readable, good if the team is data-oriented |
| **Modern .NET or Spring Boot** | Same language you know, but a clean architecture rather than an upgrade |

Pick one and commit to it before you start — changing target mid-way wastes the PRD.

Put the new application in a **new folder**, e.g. `app/`. Leave `dotnet/` and `java/`
untouched so you can compare behaviour later.

## Step 1: Let Copilot read the legacy application

Open Copilot Chat in agent mode with the legacy folder in context and ask it to
characterise the application. You are not asking for code yet.

```
You are analysing a legacy application that we are going to rewrite. Read #codebase in the
dotnet/ folder (or java/) and produce a factual characterization of what it does. Cover:
- Every HTTP route, its inputs, and its outputs
- The data model: entities, fields, types, constraints, and relationships
- Validation rules, including exactly what is rejected and with what response
- Search and filtering semantics — is search case sensitive? does it match partial words? which fields?
- How images are located and served, and what happens when one is missing
- Startup behavior: migrations, seed data import, and idempotency
- Configuration: every environment variable and what it controls
- Health and readiness endpoints and what makes each one fail
- Anything surprising, inconsistent, or clearly a bug
Do not propose improvements yet. Describe only what is there, and cite the files you found
each behavior in.
```

Read the result against the code. This is the step people skip, and it is the step that
decides whether the rewrite works. Correct anything Copilot got wrong before continuing —
also check [`dotnet/README.md`](../../dotnet/README.md) or
[`java/README.md`](../../java/README.md), which document the stable routes and
configuration.

## Step 2: Turn the characterization into a PRD

Now ask for the specification. A PRD describes the product, not the implementation — no
framework names, no class names, no SQL.

```
Using the characterization above, write a Product Requirements Document to docs/PRD.md for
a rewrite of this application. Structure it as:
1. Purpose and context — what this product is for and who uses it
2. Users and their goals
3. Functional requirements — numbered, testable statements ("The system shall ...")
4. Data requirements — entities, fields, constraints, and the seed dataset
5. Non-functional requirements — performance, scalability, availability, security, observability
6. Interface requirements — pages, routes, and their expected behavior
7. Out of scope — what we are deliberately not building
8. Open questions — anything the legacy code did not make clear
Rules:
- Every requirement must be testable and numbered so we can reference it later
- Describe behavior, never implementation. No framework, library, class, or table names
- Where the legacy behavior looks like a bug, list it under Open questions rather than
  silently specifying it
```

**Now do the actual work: review the PRD.** Read it as if you were the product owner.
Things worth arguing with:

- Requirements that only exist because the old code happened to do it that way.
- Behaviour the old app got wrong that you do not want to reproduce.
- Missing requirements — 198 figures, 20 categories, image-per-figure, the import flow.
- Open questions. Answer them in the document; do not leave them for the code.

Edit `docs/PRD.md` directly. This file is the contract between you and Copilot for the
rest of the challenge.

> Optional: if you want a more formal version of this workflow, look at
> [GitHub Spec Kit](https://github.com/github/spec-kit), which structures
> specify → plan → tasks → implement as explicit commands.

## Step 3: Turn the PRD into an implementation plan

```
Read docs/PRD.md. Produce docs/PLAN.md: a technical implementation plan for building this
product as <your chosen stack>.
- Propose the architecture: application structure, data access, templating or UI approach
- Target Azure Container Apps with a managed <Azure SQL Database | Azure Database for PostgreSQL>
  and product images served from Azure storage
- Define the database schema that satisfies the data requirements
- List the work as an ordered set of small tasks, each with the files it touches, the PRD
  requirement IDs it satisfies, and how we will verify it
- Call out any requirement in the PRD you cannot satisfy, and say why
- Do not write application code yet
```

Review the plan the same way. It is far cheaper to fix "the plan puts search in the wrong
layer" than to fix it after three hundred lines exist.

## Step 4: Build it, task by task

Work through `docs/PLAN.md` one task at a time. After each task, run the app and check the
behaviour against the PRD requirement it claims to satisfy.

```
Implement task N from docs/PLAN.md in the app/ folder. Follow docs/PRD.md for behavior.
Write tests for the requirements this task satisfies. Stop when the task is complete and
tell me what to verify.
```

Two habits that make the difference:

- **Commit after every accepted task.** If a later task goes wrong you lose one task, not
  a morning.
- **Compare against the legacy app.** It is still running on the VM from Challenge 0. Open
  both side by side and check the same search, the same category, the same figure.

Get the application running locally against a local database before you go anywhere near
Azure.

## Step 5: Deploy to Azure

From here the work is identical to path A, so follow those steps against your new
application folder. Open the path A walkthrough whose **database** matches what your PRD
chose — [Azure SQL](../ch01-A/dotnet.md) or [PostgreSQL](../ch01-A/java.md) — and work
through steps 2 to 6:

1. **Use a cloud database** and load the seed data from `data/catalog.json`.
2. **Package as a Docker container** for your new stack and test it locally.
3. **Create an Azure Container Registry and build there.**
4. **Let Azure services reach the database.**
5. **Deploy to Azure Container Apps.**

Skip step 1 there (it upgrades the legacy framework, which you no longer have) and adapt
the Dockerfile prompt in step 3 to your chosen runtime.

Ask Copilot for the Dockerfile and the Bicep exactly as path A does — the prompts there
work for any stack once you tell it which one you are on.

## Verify

Check the new application against the PRD, and against the legacy app still running on the
VM:

- The catalog page lists 198 figures across 20 categories.
- Search and category filtering behave the way the PRD says they do.
- A figure detail page opens and its photograph loads.
- Health and readiness endpoints exist and report the database correctly.
- Every numbered requirement in `docs/PRD.md` is either satisfied or explicitly listed as
  not done.

## What to take away

The interesting question is not whether the rewrite worked. It is **where it went wrong**,
and the answer is almost always the same: somewhere the PRD was vague. Note those places —
that is the transferable lesson.

If someone at your table took path A, compare: how long each took, what each of you spent
your review time on, and which application you would rather own in six months.

---

**Challenge:** [ch01-B](../../challenges/ch01-B.md) ·
**Other path:** [ch01-A](../../challenges/ch01-A.md) ·
**Next solution:** [ch02](../ch02/README.md)
