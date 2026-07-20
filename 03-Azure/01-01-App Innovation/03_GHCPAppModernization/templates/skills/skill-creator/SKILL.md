---
name: skill-creator
description: >-
  Create new skills, modify and improve existing skills, and measure skill
  performance. Use whenever the user wants to create a skill from scratch,
  turn an existing workflow or conversation into a skill, edit or optimize an
  existing SKILL.md, run test prompts against a skill, or improve a skill's
  description for better triggering accuracy — even if they don't explicitly
  say the word "skill" (e.g. "package this knowledge for the agent",
  "make this repeatable", "teach Copilot how we do X").
  NOT for: creating custom agents (.agent.md) or MCP server configuration.
---

<!--
  Adapted from Anthropic's skill-creator skill (github.com/anthropics/skills,
  Apache 2.0). Trimmed to be platform-neutral: no Anthropic-specific eval
  viewer/scripts; the iterate-with-tests loop is preserved as a manual workflow.
  Copy to: <target-repo>/.github/skills/skill-creator/SKILL.md
-->

# Skill Creator

A skill for creating new skills and iteratively improving them.

At a high level, creating a skill goes like this:

1. Decide what the skill should do and roughly how it should do it
2. Write a draft of the skill
3. Create a few realistic test prompts and run the agent-with-the-skill on them
4. Evaluate results with the user (qualitatively, and quantitatively if the output is verifiable)
5. Rewrite the skill based on feedback
6. Repeat until satisfied; then optimize the description for triggering

Figure out where the user is in this process and jump in there. If they already have a draft, go straight to test/iterate. If they say "just vibe with me, no evals", do that instead.

## Step 1 — Capture Intent

The current conversation might already contain the workflow the user wants to capture ("turn this into a skill"). If so, extract from history first: tools used, sequence of steps, corrections the user made, input/output formats. Confirm with the user before proceeding.

Establish:

1. What should this skill enable the agent to do?
2. When should it trigger? (specific user phrases/contexts)
3. What's the expected output format?
4. Should there be test cases? Skills with objectively verifiable outputs (file transforms, data extraction, code generation, fixed workflow steps) benefit from them. Subjective outputs (writing style, design) often don't. Suggest a default, let the user decide.

Proactively ask about edge cases, example files, success criteria, and dependencies. Research available docs/similar skills in parallel where possible to reduce burden on the user.

## Step 2 — Write the SKILL.md

### Anatomy of a skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled resources (optional)
    ├── scripts/    — executable code for deterministic/repetitive tasks
    ├── references/ — docs loaded into context as needed
    └── assets/     — files used in output (templates, icons, fonts)
```

### Frontmatter

- **name**: unique identifier, lowercase, hyphens for spaces
- **description**: the primary triggering mechanism. Include both WHAT the skill does AND specific contexts for WHEN to use it. All "when to use" info goes here, not in the body. Agents tend to *undertrigger* skills, so make descriptions a little "pushy": instead of "How to build a dashboard for internal data", write "How to build a dashboard for internal data. Use this whenever the user mentions dashboards, data visualization, or wants to display any kind of company data, even if they don't explicitly ask for a 'dashboard'."

### Progressive disclosure

Skills use a three-level loading system — design for it:

1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — in context whenever the skill triggers (keep under ~500 lines)
3. **Bundled resources** — loaded only as needed (unlimited; scripts can run without being loaded)

Key patterns:
- If SKILL.md approaches 500 lines, add hierarchy: move detail into `references/` with clear pointers about when to read each file.
- For large reference files (>300 lines), include a table of contents.
- When a skill supports multiple domains/variants, organize by variant so the agent reads only the relevant file:

```
cloud-deploy/
├── SKILL.md          (workflow + selection logic)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

### Writing style

- Prefer the imperative form in instructions.
- Explain **why** things matter instead of heavy-handed MUSTs. If you find yourself writing ALWAYS or NEVER in all caps, that's a yellow flag — reframe with reasoning so the model understands why it's important.
- Keep the skill general, not overfit to specific examples.
- Prefer decision tables and commands over prose.
- Defining output formats — be explicit:

```markdown
## Report structure
Use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

- Include examples:

```markdown
## Commit message format
**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Principle of lack of surprise

A skill's contents should not surprise the user given its description. Never include malware, exploit code, or content facilitating unauthorized access or data exfiltration.

## Step 3 — Test Cases

Write 2–3 realistic test prompts — the kind of thing a real user would actually type, with concrete detail (file paths, column names, casual phrasing). Share them with the user: "Here are the test cases I'd like to try — look right, or want to add more?"

Save them so they're reusable, e.g. `evals/evals.json` next to the skill:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

Then for each test case, run the task twice and compare:
- **With skill**: agent has the skill available
- **Baseline**: no skill (new skill) or the previous version (improving a skill — snapshot it first)

For objectively verifiable outputs, draft assertions with descriptive names ("CSV has profit_margin column", "build succeeds"). Check programmatically with a script where possible. Don't force assertions onto subjective outputs — those need human judgment.

## Step 4 — Improve the Skill

How to think about improvements:

1. **Generalize from feedback.** The skill will be used across many prompts, not just these test cases. Rather than fiddly overfit fixes or constrictive MUSTs, try different metaphors or different patterns of working.
2. **Keep the prompt lean.** Remove things that aren't pulling their weight. Read full transcripts, not just outputs — if the skill makes the agent waste time on unproductive steps, cut the parts causing it.
3. **Explain the why.** Transmit the user's actual intent into the instructions, not just rote rules.
4. **Look for repeated work across test cases.** If every test run independently wrote a similar helper script, bundle it once in `scripts/` and tell the skill to use it.

The iteration loop: apply improvements → rerun all test cases (including baseline) → review with user → improve again. Stop when the user is happy, the feedback is all clean, or you're not making meaningful progress.

## Step 5 — Optimize the Description (triggering)

The description is what determines whether the skill ever fires. After the skill body is stable:

1. Generate ~20 realistic trigger eval queries — 8–10 should-trigger (varied phrasings, cases where the user doesn't name the skill but clearly needs it) and 8–10 should-not-trigger. The valuable negatives are **near-misses**: adjacent domains, shared keywords, contexts where another tool is more appropriate. "Write a fibonacci function" as a negative for a PDF skill tests nothing.
2. Review the query set with the user, then check each query against the description: would the agent plausibly route here? Iterate on the description wording based on failures.
3. Note: agents only consult skills for tasks they can't trivially handle alone. Simple one-step queries ("read this file") won't trigger skills regardless of description quality — make eval queries substantive.

## Communicating with the user

Users range from non-coders to experts. Pay attention to context cues: terms like "JSON" or "assertion" need serious cues that the user knows them before using them unexplained. It's fine to briefly define terms when in doubt.

## Verification checklist

- [ ] Frontmatter has `name` (kebab-case) and a pushy, trigger-rich `description`
- [ ] All "when to use" info is in the description, not the body
- [ ] SKILL.md body under ~500 lines; detail pushed to `references/`
- [ ] 2–3 realistic test prompts saved and run with/without the skill
- [ ] Repeated work across test runs bundled into `scripts/`
- [ ] Description tested against near-miss negative queries
