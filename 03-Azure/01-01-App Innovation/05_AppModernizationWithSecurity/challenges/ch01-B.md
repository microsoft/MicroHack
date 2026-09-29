# ch01-B: Rewrite from a specification

> This is **path B** of [Challenge 1](ch01.md). If you have not chosen a path
> yet, [read the chooser first](ch01.md). Path A is
> [here](ch01-A.md) — you do not need it.

## Goal

Rebuild the catalog application on a modern stack of your choosing, using the legacy
application as the **source of truth for behaviour** rather than as code to be upgraded.

The technique is **spec-driven development**. Instead of asking Copilot to change code, you
ask it to work out *what the application does and why*, write that down as a Product
Requirements Document, and only then build. The document is the artifact you review. If the
PRD is right, the code that follows tends to be right; if the PRD is vague, you find out
early and cheaply.

The target Azure architecture is identical to path A: a container on **Azure Container
Apps**, a **managed database**, images in **Azure storage**.

Work in **GitHub Codespaces** on your own fork or clone. The
[dev container](../.devcontainer/README.md) has both SDKs, Maven, Docker and the Azure
CLI, so you can build whichever stack you rewrite into without installing anything locally.
The legacy source in `dotnet/` or `java/` is now **reference
material** — the most accurate description of the business logic that exists, but not code
you are going to keep.

## Recommended steps

### Step 0 — Choose your target stack, and commit to it

The architecture is fixed; the framework is yours.

| Target | Why you might pick it |
| --- | --- |
| **Node.js + TypeScript** (Express, Fastify, or Next.js) | Fastest to generate and review, huge ecosystem, natural fit for a catalog UI |
| **Python + FastAPI** | Small and readable; good if your team is data-oriented |
| **Modern .NET or Spring Boot** | Same language you know, but a clean architecture rather than an upgrade |

Decide before you start — changing target halfway wastes the PRD. Put the new application
in a **new folder**, e.g. `app/`, and leave `dotnet/` and `java/` untouched so you can
compare behaviour later.

### Step 1 — Have Copilot read and characterize the legacy application

Open Copilot Chat in **agent mode** with the legacy folder in context. You are not asking
for code yet — you are asking for an inventory of behaviour.

```
You are analysing a legacy application we are going to rewrite. Read #codebase in the
dotnet/ folder (or java/) and produce a factual characterization of what it does. Cover:
- Every HTTP route, its inputs, and its outputs
- The data model: entities, fields, types, constraints, relationships
- Validation rules — exactly what is rejected, and with what response
- Search and filtering semantics: case sensitive? partial matches? which fields?
- How images are located and served, and what happens when one is missing
- Startup behavior: migrations, seed import, idempotency
- Configuration: every environment variable and what it controls
- Health and readiness endpoints, and what makes each one fail
- Anything surprising, inconsistent, or clearly a bug
Do not propose improvements. Describe only what is there, and cite the files you found each
behavior in.
```

**Read the result against the code.** This is the step people skip, and it is the step that
decides whether the rewrite works. [`dotnet/README.md`](../dotnet/README.md) and
[`java/README.md`](../java/README.md) document the routes and configuration — use them
to check Copilot's homework.

**Checkpoint:** you have a description of the app you actually believe.

### Step 2 — Turn the characterization into a PRD, then argue with it

A PRD describes the **product**, not the implementation: no framework names, no class
names, no SQL.

```
Using the characterization above, write a Product Requirements Document to docs/PRD.md for
a rewrite of this application. Structure it as:
1. Purpose and context      2. Users and their goals
3. Functional requirements — numbered, testable ("The system shall ...")
4. Data requirements — entities, fields, constraints, the seed dataset
5. Non-functional requirements — performance, scalability, availability, security, observability
6. Interface requirements — pages, routes, expected behavior
7. Out of scope          8. Open questions
Rules:
- Every requirement testable and numbered so we can reference it later
- Describe behavior, never implementation — no framework, library, class, or table names
- Where legacy behavior looks like a bug, list it under Open questions rather than
  silently specifying it
```

**Now do the actual work: review the PRD as if you were the product owner.** Things worth
pushing back on:

- Requirements that exist only because the old code happened to do it that way.
- Behaviour the old app got wrong that you do not want to reproduce.
- Missing requirements — 198 figures, 20 categories, one image per figure, the import flow.
- Open questions. Answer them **in the document**; do not leave them for the code.

Edit `docs/PRD.md` directly. From here on it is the agreement between you and Copilot.

> Optional: [GitHub Spec Kit](https://github.com/github/spec-kit) formalizes this workflow
> as explicit specify → plan → tasks → implement commands, if you want more structure.

**Checkpoint:** a PRD you would be comfortable handing to a contractor.

### Step 3 — Turn the PRD into an implementation plan

```
Read docs/PRD.md. Produce docs/PLAN.md: a technical implementation plan for building this
product as <your chosen stack>.
- Propose the architecture: application structure, data access, UI approach
- Target Azure Container Apps with a managed <Azure SQL Database | Azure Database for
  PostgreSQL> and product images served from Azure storage
- Define the database schema satisfying the data requirements
- List the work as ordered small tasks, each with the files it touches, the PRD requirement
  IDs it satisfies, and how we will verify it
- Call out any PRD requirement you cannot satisfy, and say why
- Do not write application code yet
```

Review the plan the same way. It is much cheaper to fix "search is in the wrong layer" now
than after three hundred lines exist.

### Step 4 — Build it, one task at a time

Work through `docs/PLAN.md` task by task. After each, run the app and check the behaviour
against the PRD requirement it claims to satisfy.

```
Implement task N from docs/PLAN.md in the app/ folder. Follow docs/PRD.md for behavior.
Write tests for the requirements this task satisfies. Stop when the task is complete and
tell me what to verify.
```

Two habits that make the difference:

- **Commit after every accepted task.** If a later task goes wrong you lose one task, not a
  morning.
- **Compare against the legacy app**, which is still running on the VM from Challenge 0.
  Open both side by side: same search, same category, same figure.

**Checkpoint:** the new application runs locally against a local database and behaves like
the old one.

### Step 5 — Deploy to Azure

From here the work is the same as path A, applied to your new application folder: a managed
database, a Dockerfile, `az acr build`, and a Container App. Ask Copilot for the Bicep and
the Dockerfile — the prompts work for any stack once you say which one you are on.

If you want the exact prompts, [path A's solution](../walkthrough/ch01-A/README.md) has
them in steps 2 to 6, and they are safe to reuse. Open the walkthrough whose **database**
matches what your PRD chose — [Azure SQL](../walkthrough/ch01-A/dotnet.md) or
[PostgreSQL](../walkthrough/ch01-A/java.md) — and ignore the framework-specific parts of
step 1 and step 3.

## Success Criteria

- The application is fully functional in Azure: browse, search, filter by category, open
  a figure detail page, and see its photograph.
- The application and the database are deployed separately, and the database is a managed
  Azure service.
- The application runs as a container on Azure Container Apps and can scale.
- No database password is committed to the repository.
- Every numbered requirement in `docs/PRD.md` is either satisfied or explicitly listed as
  not done.

## What to take away

The interesting question is not whether the rewrite worked. It is **where it went wrong** —
and the answer is almost always "somewhere the PRD was vague". Note those places; that is
the transferable lesson.

If someone at your table took path A, compare at the end: how long each took, what each of
you spent review time on, and which application you would rather own in six months. The
[wrap-up](wrapup.md) comes back to this.

## Solution — spoiler warning

[Step-by-step walkthrough with full prompts](../walkthrough/ch01-B/README.md)

---

**Challenge:** [ch01](ch01.md) · **Other path:**
[ch01-A](ch01-A.md) · **Next:** [ch02](ch02.md)
