## Data Generation Script (LEGO-Style Catalog Seed)

Generates synthetic seed data (categories, >200 catalog items, and 1024×1024 images) for the Blazor LEGO-style catalog modernization labs using Azure OpenAI (`gpt-5` & `gpt-image-1`) and `uv` for Python dependency management.

> NOTE: "LEGO-style" is used purely for educational, non‑commercial demo content. Prompts must avoid trademarked logos, specific brand/franchise names, and identifiable real people.

---
## 1. High-Level Flow
1. Load configuration from environment variables / `.env`.
2. Generate 20 categories with a single structured-output GPT call (JSON array of category objects).
3. Iteratively generate catalog items in batches (~20 per iteration) until total items > TARGET_COUNT (default 200):
	- Pass the category list AND a compact representation (names only) of already accepted items into the system or user prompt to enforce uniqueness.
 System (template): You generate unique Lego-style catalog items. Existing categories: <JSON categories>. Already used names: <comma-separated existing names>. Return ONLY a JSON array of objects with fields: 
 - name (max 6 words)
 - description (2-4 sentences, neutral, no trademarks)
 - category (must match one of existing categories)
 - imagePrompt (string) starting EXACTLY with "Photorealistic LEGO-style minifigure" (or "Photorealistic LEGO-style figure") followed by a concise comma-separated set of distinctive visual elements from the item description plus neutral style phrases: "clean background, high detail, vibrant, evenly lit, 1024x1024". 

 Hard constraints for imagePrompt:
 - Must NOT include or reference trademarked logos, specific brand names (besides the generic LEGO-style descriptor), or real people.
 - Avoid words like "logo", "official", brand franchises, or celebrity names.
 - Keep total length under ~230 characters.

 Do not include productId or filename (the script assigns those). Return ONLY raw JSON.
	- For each accepted item, assign a final `productId` (UUID v4) and derive `filename` = `<productId>.png`.
4. Persist cumulative items after each batch to allow resume if interrupted.
5. After item generation, loop through items and generate images (skip those with existing image file unless `--force-images`).
6. Finalize `catalog.json` with all fields: productId, name, description, category, filename, imagePrompt.

 The model now generates `imagePrompt` directly during item batch creation. The script no longer heuristically derives prompts.

 Required opening: "Photorealistic LEGO-style minifigure" (or "Photorealistic LEGO-style figure").
 Then: concise visual attributes (pulled from description) + fixed stylistic tail: "clean background, high detail, vibrant, evenly lit, 1024x1024".

 Forbidden content: trademarked logos, explicit brand or franchise names beyond the generic LEGO-style descriptor, copyrighted characters, real people, or personal data.

 Validation: The script may (future enhancement) enforce prefix and scan for disallowed tokens (e.g., /logo|trademark|Star Wars|Marvel/i). Currently it trusts the model but can log anomalies.
Output directory (configurable) contains structured outputs parsed directly into Pydantic models (no manual JSON munging required).
Downstream importer can derive slugs later if/when required.

```json
{
	"productId": "94b1d70c-5f4f-4ab0-9d1e-4d3d9ccaa8a1",
	"name": "Arctic Research Biologist",
	"description": "A dedicated scientist studying polar wildlife and ice samples, equipped with cold-weather gear and a portable lab kit.",
	"filename": "94b1d70c-5f4f-4ab0-9d1e-4d3d9ccaa8a1.png",
	"imagePrompt": "Photorealistic LEGO-style minifigure, arctic research biologist studying ice core, subtle snowy backdrop, high detail, vibrant, evenly lit, 1024x1024"
}
```

---
## 2. Environment Configuration
All parameters supplied via environment variables and optional `.env` file (loaded via `python-dotenv`).

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| AZURE_OPENAI_ENDPOINT | Yes | Base endpoint URL | https://my-openai-resource.openai.azure.com |
| AZURE_OPENAI_API_KEY | Yes | Azure OpenAI API key | (secret) |
| AZURE_OPENAI_API_VERSION | Yes | API version string | 2024-06-01 |
| AZURE_OPENAI_GPT5_DEPLOYMENT | Yes | Deployment name for gpt-5 | gpt5 | 
| AZURE_OPENAI_IMAGE_DEPLOYMENT | Yes | Deployment name for gpt-image-1 | gpt-image-1 |
| OUTPUT_DIR | No | Directory for generated assets | ./data_seed |
| BATCH_SIZE | No | Item batch size per loop (default 20) | 20 |
| IMAGE_SIZE | No | Image dimension (square) | 1024 |
| TARGET_COUNT | No | Total desired items (stops after exceeded) | 200 |
| PARALLEL_IMAGE_REQUESTS | No | Max concurrent image calls | 4 |
| MAX_RETRIES | No | Retry attempts for API calls | 5 |
| DRY_RUN | No | If true, skip image generation | false |
| LOG_LEVEL | No | Logging level | INFO |
### 2.1 Sample `.env`
```
AZURE_OPENAI_ENDPOINT=https://my-openai-resource.openai.azure.com
AZURE_OPENAI_API_KEY=YOUR_KEY_HERE
AZURE_OPENAI_API_VERSION=2024-06-01
AZURE_OPENAI_GPT5_DEPLOYMENT=gpt5
AZURE_OPENAI_IMAGE_DEPLOYMENT=gpt-image-1
OUTPUT_DIR=./data_seed
TARGET_COUNT=210
IMAGE_SIZE=1024
PARALLEL_IMAGE_REQUESTS=4
MAX_RETRIES=5
```

---
## 3. Prompts & Structured Output Strategy
### 3.1 Categories Prompt (Single Call)
System: You are a data generator producing a JSON array of exactly 20 distinct category objects for a Lego-style figure catalog. Each object must have name (2-3 words) and slug (kebab-case). Return ONLY JSON.

### 3.2 Items Batch Prompt
System (template): You generate unique Lego-style catalog items. Existing categories: <JSON categories>. Already used names: <comma-separated existing names>. Return ONLY a JSON root object with key `items` whose value is an array of objects with fields: name (max 6 words), description (2-4 sentences, neutral, no trademarks), category (must match one of existing categories), imagePrompt (prefix rules). Do not include productId or filename (script assigns those). The SDK enforces this schema via structured outputs.

1. Validates JSON (schema). 
2. Dedupes by name (case-insensitive). 
3. Assigns UUID `productId` and constructs `filename`.

### 3.3 Iterative Growth
After each accepted batch, regenerate compressed item name list (or hashed summary if token pressure arises) and feed into the next batch prompt to maintain uniqueness until item count ≥ TARGET_COUNT.

### 3.4 Image Prompt Generation
The model itself generates `imagePrompt` using constrained instructions; no local heuristic expansion occurs.

---
– Exponential backoff (e.g., base 1.5s, jitter) for 429/5xx responses.
– Max retries per call (configurable via MAX_RETRIES).
– Automatic partial progress persistence (write intermediate `catalog.partial.json` after each batch & after every N images).
– Resume logic: if `catalog.json` exists and `--resume` flag used, load existing items and continue missing images only.

---
## 4. Idempotency Rules
| Scenario | Behavior |
|----------|----------|
| Re-run without changes | Skips category regeneration if `categories.json` exists (unless `--force-categories`). |
| Existing `catalog.json` < TARGET_COUNT | Continues item generation. |
| Existing image file | Skip unless `--force-images` specified. |
| DRY_RUN=true | Skips image generation entirely. |

---
## 5. Installation & Execution (with uv)
### 5.1 Prerequisites
– Python 3.11+ (recommended)
– `uv` installed (https://github.com/astral-sh/uv)

### 5.2 Project Setup
If a `pyproject.toml` is provided (to be added later):
```
uv sync
```

If not yet present, you can initialize (illustrative; actual file will be committed later):
```
uv init --package lego-data-generator
```
Dependencies already defined in `pyproject.toml`; run `uv sync` to install.

### 5.3 Running the Script
```
uv run python -m data_generator \
	--target-count 210 \
	--batch-size 20 \
	--parallel-image-requests 4
```

Flags (proposed):
| Flag | Description |
|------|-------------|
| --target-count INT | Override TARGET_COUNT env |
| --batch-size INT | Override BATCH_SIZE env |
| --force-categories | Regenerate categories even if file exists |
| --force-images | Regenerate all images |
| --resume | Continue from existing partial catalog/images |
| --dry-run | Skip image generation regardless of env |
| --no-validate | Skip JSON schema validation (debug only) |

### 5.4 Output Verification
After completion:
```
cat data_seed/categories.json | jq length   # should be 20
cat data_seed/catalog.json | jq length      # should be >= target
ls data_seed/images | wc -l                # number of PNGs
```

---
## 6. JSON Validation
Schema (informal):
```json
{
	"type": "object",
	"required": ["productId", "name", "description", "category", "filename"],
	"properties": {
		"productId": { "type": "string", "pattern": "^[0-9a-fA-F-]{36}$" },
		"name": { "type": "string", "minLength": 3, "maxLength": 80 },
		"description": { "type": "string", "minLength": 20, "maxLength": 1200 },
		"category": { "type": "string" },
		"filename": { "type": "string", "pattern": "^[0-9a-fA-F-]{36}\.png$" },
		"imagePrompt": { "type": "string" }
	}
}
```
Validation steps:
1. Categories: ensure exactly 20 unique names.
2. Items: ensure category exists; name uniqueness (case-insensitive); UUID validity.
3. Report & discard invalid items; log reasons.

---
## 7. Concurrency Model for Images
– Use an asyncio semaphore (size = PARALLEL_IMAGE_REQUESTS).
– Each task: build prompt -> POST image request -> download binary -> atomic write (temp + rename). 
– Progress bar (tqdm) updated on completion.
– On failure after retries, record in `failed_images.log` for re-run.

---
## 8. Cost & Quota Considerations
Rough guideline (adjust per pricing region):
– Text generations: ~ (items/50 + 1 category call) requests. Keep prompts concise (only list names of existing items, not full descriptions, to save tokens).
– Image generations: N = TARGET_COUNT (one per item) at 1024x1024. Provide optional `--skip-images` for low-cost dry runs.

Optimization ideas:
| Technique | Benefit |
|-----------|---------|
| Name-only memory of previous items | Reduces prompt tokens |
| Batch size tuning | Balances uniqueness vs token size |
| Parallel images | Shorter wall time |
| Resume mode | Avoids re-paying for successful steps |

---
## 9. Error Handling Summary
| Failure | Handling |
|---------|----------|
| 429 / 5xx text call | Retry with backoff until MAX_RETRIES, else abort batch |
| Malformed JSON | Attempt single regeneration (with stricter system instruction), else skip batch |
| Duplicate names | Discard duplicates; if effective yield low, request supplemental mini-batch |
| Image generation failure | Retry; if still failing, record ID and continue |
| Disk write error | Abort (fail fast) |

---
## 10. Integration with .NET Importer
The generated `catalog.json` will be consumed at application startup if the database is empty. Since the application (per design doc) currently expects sequential IDs (e.g., `LF-0001`) you have options:
1. Keep UUIDs and adjust importer to accept them directly.
2. Map UUIDs to sequential `LF-xxxx` during import while preserving original UUID in an `ExternalId` column (future-friendly for traceability).

Recommended: importer detects UUID pattern; if so, generates sequential internal ids while storing original as metadata.

---
## 11. Security & Compliance Notes
– Do not log full API keys.
– Avoid prompts that request or could yield sensitive personal data.
– Strip or reject descriptions containing brand names/trademarks (simple blacklist regex pass) – optional enhancement.
– Ensure generated images are stored locally and not publicly published without review.

---
## 12. Future Enhancements
| Enhancement | Rationale |
|-------------|-----------|
| Parallel category + item generation with streaming validation | Faster startup | 
| Automatic prompt quality scoring | Filter low-quality descriptions |
| Alternative image size variants (thumbnail) | Save runtime in Blazor UI |
| Hash-based duplicate image detection | Avoid near-identical outputs |
| Telemetry (OpenTelemetry traces) | Observe generation performance |

---
## 13. Quick Start (TL;DR)
```
# 1. Create .env with required Azure OpenAI values (see sample above)
# 2. Install deps
uv sync
# 3. Run generator (first full run, 210 items for buffer)
uv run python -m data_generator --target-count 210
# 4. (Optional) Generate missing images only later
uv run python -m data_generator --resume --force-images
```

Result: `data_seed/catalog.json` + `data_seed/images/*.png` ready for the Blazor importer.

---
## 14. Troubleshooting
| Symptom | Possible Cause | Action |
|---------|----------------|-------|
| Few items generated per batch | Many duplicates | Reduce batch size or enhance uniqueness prompt section |
| JSON parse errors | Model returned text wrappers | Strengthen system instruction: "Return ONLY JSON" & trim | 
| Slow image generation | Serial execution | Increase PARALLEL_IMAGE_REQUESTS (watch rate limits) |
| Resuming skips images | Filenames already exist | Use `--force-images` |

---
## 15. License & Attribution
Generated data/images are synthetic. Review before redistribution. Respect Azure OpenAI usage policies.

---