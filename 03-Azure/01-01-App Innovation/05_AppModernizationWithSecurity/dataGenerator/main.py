"""CLI tool to generate synthetic Lego-style catalog data using Azure OpenAI Responses API.

Features:
 - Generates 20 category objects (keeps only names in categories.json)
 - Iteratively generates item batches (default 20 each) until target count reached
 - Model directly returns imagePrompt (no local heuristic building)
 - Optionally generates images with concurrency controls
 - Simple resume & idempotent behavior (skip existing artifacts unless forced)

Environment variables (see .env.sample) control defaults; CLI flags can override.

Assumptions / Notes:
 - Uses Azure OpenAI via AzureOpenAI client. Ensure deployments exist matching provided names.
 - Uses Responses API for both text (categories/items) and images.
 - Structured outputs: We supply a JSON schema and parse into Pydantic models for safety.
 - For simplicity, validation is minimal beyond Pydantic + prefix check for imagePrompt.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import json
import logging
from pathlib import Path
import uuid
from typing import List, Optional

from openai import AzureOpenAI
from pydantic import BaseModel, Field, field_validator
from dotenv import load_dotenv
import os


# ----------------------------- Pydantic Models ----------------------------- #


class CategoryObject(BaseModel):
    """Single category with display name and slug."""

    name: str = Field(min_length=2, max_length=40)
    slug: str = Field(min_length=2, max_length=60)


class CategoryList(BaseModel):
    """Wrapper root object required for structured output parsing."""

    categories: List[CategoryObject]

    @field_validator("categories")
    @classmethod
    def ensure_20_unique(cls, v: List[CategoryObject]):  # noqa: D401
        names = [c.name.lower() for c in v]
        if len(v) != 20:
            raise ValueError("Expected exactly 20 categories")
        if len(set(names)) != 20:
            raise ValueError("Duplicate category names detected")
        return v


class GeneratedItem(BaseModel):
    """Model returned by LLM for each item prior to assigning productId/filename."""

    name: str = Field(min_length=3, max_length=80)
    description: str = Field(min_length=20, max_length=1200)
    category: str
    imagePrompt: str = Field(min_length=30, max_length=260)

    @field_validator("imagePrompt")
    @classmethod
    def prompt_prefix(cls, v):  # noqa: D401
        low = v.lower()
        if not (low.startswith("photorealistic lego-style mini") or low.startswith("photorealistic lego-style figure")):
            raise ValueError("imagePrompt must start with required prefix")
        forbidden = ["logo", "official", "star wars", "marvel", "dc comics", "harry potter", "ninjago"]
        if any(tok in low for tok in forbidden):
            raise ValueError("imagePrompt contains forbidden brand/franchise reference")
        return v


class GeneratedItemsWrapper(BaseModel):
    """Root wrapper for structured batch generation."""

    items: List[GeneratedItem]


class CatalogItem(GeneratedItem):
    productId: uuid.UUID
    filename: str

    @classmethod
    def from_generated(cls, gen: GeneratedItem) -> "CatalogItem":
        pid = uuid.uuid4()
        return cls(
            productId=pid,
            filename=f"{pid}.png",
            **gen.dict(),
        )


# ----------------------------- Config Handling ----------------------------- #


class Config(BaseModel):
    azure_openai_endpoint: str
    azure_openai_api_key: str
    azure_openai_api_version: str
    gpt_deployment: str
    image_deployment: str
    output_dir: Path = Field(default=Path("./data_seed"))
    target_count: int = 200
    batch_size: int = 20
    image_size: int = 1024
    parallel_image_requests: int = 4
    max_retries: int = 5
    dry_run: bool = False
    log_level: str = "INFO"

    @classmethod
    def from_env(cls, overrides: dict) -> "Config":
        env = os.environ
        kwargs = dict(
            azure_openai_endpoint=env.get("AZURE_OPENAI_ENDPOINT", ""),
            azure_openai_api_key=env.get("AZURE_OPENAI_API_KEY", ""),
            azure_openai_api_version=env.get("AZURE_OPENAI_API_VERSION", ""),
            gpt_deployment=env.get("AZURE_OPENAI_GPT5_DEPLOYMENT", env.get("AZURE_OPENAI_GPT_DEPLOYMENT", "")),
            image_deployment=env.get("AZURE_OPENAI_IMAGE_DEPLOYMENT", ""),
            output_dir=Path(env.get("OUTPUT_DIR", "./data_seed")),
            target_count=int(env.get("TARGET_COUNT", 200)),
            batch_size=int(env.get("BATCH_SIZE", 20)),  # Force default 20 per new requirement
            image_size=int(env.get("IMAGE_SIZE", 1024)),
            parallel_image_requests=int(env.get("PARALLEL_IMAGE_REQUESTS", 4)),
            max_retries=int(env.get("MAX_RETRIES", 5)),
            dry_run=env.get("DRY_RUN", "false").lower() == "true",
            log_level=env.get("LOG_LEVEL", "INFO"),
        )
        kwargs.update({k: v for k, v in overrides.items() if v is not None})
        return cls(**kwargs)


# ----------------------------- OpenAI Helpers ------------------------------ #


def azure_client(cfg: Config) -> AzureOpenAI:
    """Instantiate Azure OpenAI client."""
    return AzureOpenAI(
        azure_endpoint=cfg.azure_openai_endpoint,
        api_key=cfg.azure_openai_api_key,
        api_version=cfg.azure_openai_api_version,
    )


def generate_categories(client: AzureOpenAI, cfg: Config, force: bool) -> List[str]:
    out_file = cfg.output_dir / "categories.json"
    if out_file.exists() and not force:
        logging.info("Using existing categories at %s", out_file)
        return json.loads(out_file.read_text())

    system = (
        "You are a data generator producing a JSON object with key 'categories' containing exactly 20 "
        "distinct category objects for a Lego-style figure catalog. Each object must have name (2-3 words) and slug (kebab-case)."
    )
    response = client.responses.parse(
        model=cfg.gpt_deployment,
        input=[
            {"role": "system", "content": system},
            {"role": "user", "content": "Generate categories now."},
        ],
        text_format=CategoryList,
    )
    wrapped: CategoryList = response.output_parsed  # type: ignore[assignment]
    names = [c.name for c in wrapped.categories]
    cfg.output_dir.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(names, indent=2))
    logging.info("Wrote categories.json with %d categories", len(names))
    return names


def generate_item_batch(client: AzureOpenAI, cfg: Config, categories: List[str], existing_names: List[str], batch_size: int) -> List[GeneratedItem]:
    system = (
        "You generate unique Lego-style catalog items. Return JSON object with key 'items'. Rules: "
        "Each item has name (<=6 words), description (2-4 neutral sentences, no trademarks), category (must match one of provided), "
        "imagePrompt starting EXACTLY with 'Photorealistic LEGO-style minifigure' or 'Photorealistic LEGO-style figure' followed by concise visual descriptors and 'clean background, high detail, vibrant, evenly lit, 1024x1024'. "
        "Avoid brand/franchise names, logos, real people."
    )
    user = (
        f"Existing categories: {json.dumps(categories)}\n"
        f"Already used names: {', '.join(existing_names) if existing_names else 'NONE'}\n"
        f"Generate {batch_size} new distinct items."
    )
    response = client.responses.parse(
        model=cfg.gpt_deployment,
        input=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        text_format=GeneratedItemsWrapper,
    )
    wrapped: GeneratedItemsWrapper = response.output_parsed  # type: ignore[assignment]
    # Deduplicate by name against existing
    existing_set = {n.lower() for n in existing_names}
    new_unique: List[GeneratedItem] = []
    for itm in wrapped.items:
        if itm.name.lower() in existing_set:
            continue
        if itm.category not in categories:
            continue
        new_unique.append(itm)
        existing_set.add(itm.name.lower())
    return new_unique


def save_catalog(items: List[CatalogItem], cfg: Config):
    out_file = cfg.output_dir / "catalog.json"
    data = [
        {
            "productId": str(i.productId),
            "name": i.name,
            "description": i.description,
            "category": i.category,
            "filename": i.filename,
            "imagePrompt": i.imagePrompt,
        }
        for i in items
    ]
    out_file.write_text(json.dumps(data, indent=2))
    logging.info("Catalog saved with %d items", len(items))


async def _generate_single_image(client: AzureOpenAI, cfg: Config, item: CatalogItem, images_dir: Path, semaphore: asyncio.Semaphore, force: bool):
    """Generate a single image using the Responses API image_generation tool.

    The earlier approach using modalities / image params is replaced with the
    tool invocation style:
        tools=[{"type": "image_generation"}]
    and extracting base64 from outputs of type 'image_generation_call'.
    """
    path = images_dir / item.filename
    if path.exists() and not force:
        return
    async with semaphore:
        last_err: Optional[Exception] = None
        # Prefer dedicated image deployment; fall back to text deployment if not set.
        model_for_image = cfg.image_deployment or cfg.gpt_deployment
        prompt = item.imagePrompt
        for attempt in range(cfg.max_retries):
            try:
                # Use Images API (generate) instead of Responses image tool.
                resp = await asyncio.to_thread(
                    client.images.generate,
                    model=model_for_image,
                    prompt=prompt,
                    size=f"{cfg.image_size}x{cfg.image_size}",
                )
                if not getattr(resp, "data", None):
                    raise ValueError("No data field in image response")
                image_b64 = resp.data[0].b64_json  # type: ignore[index]
                binary = base64.b64decode(image_b64)
                tmp = path.with_suffix(".tmp")
                tmp.write_bytes(binary)
                tmp.replace(path)
                return
            except Exception as e:  # noqa: BLE001
                last_err = e
                backoff = min(2 ** attempt * 0.5, 8)
                await asyncio.sleep(backoff)
        logging.error("Giving up generating image for %s: %s", item.productId, last_err)


async def generate_images(client: AzureOpenAI, cfg: Config, items: List[CatalogItem], force: bool):
    if cfg.dry_run:
        logging.info("DRY_RUN=true -> skipping image generation")
        return
    images_dir = cfg.output_dir / "images"
    images_dir.mkdir(parents=True, exist_ok=True)
    semaphore = asyncio.Semaphore(cfg.parallel_image_requests)
    tasks = [
        _generate_single_image(client, cfg, item, images_dir, semaphore, force)
        for item in items
    ]
    done = 0
    for coro in asyncio.as_completed(tasks):
        try:
            await coro
        except Exception as e:  # noqa: BLE001
            logging.error("Image generation failed: %s", e)
        done += 1
        if done % 10 == 0 or done == len(tasks):
            logging.info("Images progress: %d/%d", done, len(tasks))


def load_existing_catalog(path: Path) -> List[CatalogItem]:
    if not path.exists():
        return []
    data = json.loads(path.read_text())
    items: List[CatalogItem] = []
    for obj in data:
        try:
            items.append(
                CatalogItem(
                    productId=uuid.UUID(obj["productId"]),
                    name=obj["name"],
                    description=obj["description"],
                    category=obj["category"],
                    filename=obj["filename"],
                    imagePrompt=obj.get("imagePrompt", ""),
                )
            )
        except Exception as e:  # noqa: BLE001
            logging.warning("Skipping invalid existing item: %s", e)
    return items


def run(cfg: Config, args):
    logging.basicConfig(
        level=getattr(logging, cfg.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(message)s",
    )
    client = azure_client(cfg)
    cfg.output_dir.mkdir(parents=True, exist_ok=True)

    categories = generate_categories(client, cfg, force=args.force_categories)

    catalog_path = cfg.output_dir / "catalog.json"
    items: List[CatalogItem] = []
    if args.resume and catalog_path.exists():
        items = load_existing_catalog(catalog_path)
        logging.info("Loaded %d existing items", len(items))

    # Generate items until target
    while len(items) < cfg.target_count:
        batch = generate_item_batch(
            client,
            cfg,
            categories,
            [i.name for i in items],
            cfg.batch_size,
        )
        if not batch:
            logging.warning("Received empty/duplicate batch; stopping to avoid loop")
            break
        catalog_items = [CatalogItem.from_generated(b) for b in batch]
        items.extend(catalog_items)
        save_catalog(items, cfg)
        logging.info("Items so far: %d / %d", len(items), cfg.target_count)
        if len(items) >= cfg.target_count:
            break

    # Trim extra beyond target (keep deterministic order)
    if len(items) > cfg.target_count:
        items = items[: cfg.target_count]
        save_catalog(items, cfg)
        logging.info("Trimmed catalog to target_count=%d", cfg.target_count)

    # Images
    asyncio.run(generate_images(client, cfg, items, force=args.force_images))

    logging.info("Generation complete")


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Lego catalog data generator")
    p.add_argument("--target-count", type=int, dest="target_count")
    p.add_argument("--batch-size", type=int, dest="batch_size")
    p.add_argument("--force-categories", action="store_true")
    p.add_argument("--force-images", action="store_true")
    p.add_argument("--resume", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    return p


def cli(argv: Optional[List[str]] = None):  # Entry point
    load_dotenv()
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    overrides = {
        "target_count": args.target_count,
        "batch_size": args.batch_size,
        "dry_run": args.dry_run or None,
    }
    cfg = Config.from_env(overrides)
    run(cfg, args)


if __name__ == "__main__":  # pragma: no cover
    cli()
