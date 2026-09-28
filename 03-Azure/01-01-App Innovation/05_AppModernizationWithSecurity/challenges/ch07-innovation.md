# ch07-innovation: let a customer ask the catalog a question

This optional challenge is for teams who want to add an AI-powered experience to the
modernized catalog. Keep the existing application reliable, then add one useful feature
that helps customers discover the right LEGO figure.

The catalog has exact search today. That works when a customer knows the product name,
but not when they ask for "a space figure with a dragon vibe" or "something wintery
under twenty euros". Your job is to make that kind of discovery possible without
inventing products that are not in the catalog.

Use the stack you chose in [ch00](ch00.md): .NET with Azure SQL Database, or
Java with Azure Database for PostgreSQL. The AI feature may live inside that app or in a
small service it calls, but the browser should call your server, not Azure AI services
directly.

## Choose an innovation track

Pick one track and make it work end to end. If you finish early, polish it before adding
a second feature.

## 1. Grounded recommendation chat

- Add a chat or question box that answers catalog questions in natural language.
- Retrieve relevant products from the catalog before calling a model.
- Require answers to cite real product IDs or product links.
- Return a friendly "I could not find that" response when the catalog does not support the
  answer.

The refusal path is as important as the happy path. A confident fake recommendation is
worse than the old search box.

## 2. Semantic search and browsing

- Add vector or hybrid search over product names, descriptions, categories, and image
  metadata.
- Keep the classic search available so users can compare results.
- Use Azure AI Search, PostgreSQL vector capabilities, Azure SQL vector support, or another
  approved search service.
- Explain how often the index is rebuilt and which catalog fields are included.

Start by proving retrieval works without generation. If the right products are not in the
results, a model will not rescue the experience.

## 3. Product explanations and localization

- Add an "explain this figure" or "translate this description" feature on the detail page.
- Keep original catalog text as the source of truth.
- Label generated or translated content clearly.

This is a good track when you want a small UI change with a clear user benefit.

## 4. Personalized or guided recommendations

- Simulate favorites, recently viewed figures, or a simple user profile.
- Recommend related products using category, description, price, or embedding similarity.
- Explain why each recommendation appeared.
- Avoid storing real personal data for a workshop experiment.

A recommendation without an explanation is hard to trust and hard to debug.

## 5. Responsible AI and evaluation

- Write a small set of test questions: answerable, ambiguous, outside the catalog,
  unsafe, and prompt-injection attempts.
- Measure whether answers cite real products, abstain correctly, and stay within latency
  and cost expectations.
- Add content-safety checks where appropriate.
- Log useful telemetry without storing secrets or unnecessary raw prompts.

The best demo is one good answer, one honest refusal, and one attack that fails safely.

## Implementation guidance

- Keep the catalog database authoritative; indexes and embeddings are derived data.
- Use managed identity where possible, and never expose Azure keys to the frontend.
- Put the AI feature behind a configuration switch or separate route so the original
  catalog still works if AI services are unavailable.

## Coach note

Ask a coach before creating paid AI resources or model deployments. Capacity, region, and
responsible-AI rules may differ by subscription.

> Tip: Build in this order: retrieve real products, generate from only those products,
> validate citations, then add the user interface.

---

**Previous:** [ch06-sre-agent](ch06-sre-agent.md) · **Other optional challenge:** [ch07-enterprise](ch07-enterprise.md) · **Wrap-up:** [wrapup](wrapup.md)
