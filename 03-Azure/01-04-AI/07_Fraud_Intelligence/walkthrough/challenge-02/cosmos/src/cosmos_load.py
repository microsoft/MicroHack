import argparse
import asyncio
from datetime import datetime, timezone
import gzip
import hashlib
import json
import logging
import os
from pathlib import Path
from typing import Any

from azure.cosmos import PartitionKey
from azure.cosmos.aio import CosmosClient
from azure.identity.aio import DefaultAzureCredential


LOGGER = logging.getLogger("load_cosmos")
DEFAULT_CONTAINERS = ["dim-bank", "fact-laundering-pattern-txn"]
SYSTEM_FIELDS = {"_rid", "_self", "_etag", "_attachments", "_ts"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export and import Azure Cosmos DB containers as compressed JSON Lines."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    export_parser = subparsers.add_parser("export", help="Export containers.")
    add_connection_args(export_parser)
    export_parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/cosmos_exports/aml"),
    )
    export_parser.add_argument(
        "--container",
        action="append",
        help="Container to export; repeat to select multiple. Defaults to the AML containers.",
    )

    import_parser = subparsers.add_parser("import", help="Import an export package.")
    add_connection_args(import_parser)
    import_parser.add_argument("--input", type=Path, required=True)
    import_parser.add_argument(
        "--container",
        action="append",
        help="Container to import; repeat to select multiple. Defaults to all in the manifest.",
    )
    import_parser.add_argument("--batch-size", type=int, default=500)
    import_parser.add_argument("--concurrency", type=int, default=32)
    import_parser.add_argument(
        "--create-containers",
        action="store_true",
        help="Create the database and missing containers using the manifest.",
    )

    args = parser.parse_args()
    if not args.endpoint:
        parser.error("set COSMOS_ENDPOINT or pass --endpoint")
    if args.command == "import" and (args.batch_size < 1 or args.concurrency < 1):
        parser.error("--batch-size and --concurrency must be positive")
    return args


def add_connection_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--endpoint", default=os.getenv("COSMOS_ENDPOINT"))
    parser.add_argument("--database", default=os.getenv("COSMOS_DATABASE", "aml"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


async def export_container(database: Any, name: str, output_dir: Path) -> dict[str, Any]:
    container = database.get_container_client(name)
    properties = await container.read()
    partition_key_paths = properties["partitionKey"]["paths"]
    output_path = output_dir / f"{name}.jsonl.gz"
    count = 0

    with gzip.open(output_path, "wt", encoding="utf-8", newline="\n") as output_file:
        async for item in container.query_items("SELECT * FROM c"):
            document = {
                key: value for key, value in item.items() if key not in SYSTEM_FIELDS
            }
            output_file.write(
                json.dumps(document, ensure_ascii=False, separators=(",", ":"))
            )
            output_file.write("\n")
            count += 1
            if count % 1000 == 0:
                LOGGER.info("%s: %d documents exported", name, count)

    LOGGER.info("%s complete: %d documents", name, count)
    return {
        "name": name,
        "file": output_path.name,
        "partitionKeyPaths": partition_key_paths,
        "documents": count,
        "sha256": sha256_file(output_path),
    }


async def export_data(args: argparse.Namespace, database: Any) -> None:
    args.output.mkdir(parents=True, exist_ok=True)
    containers = args.container or DEFAULT_CONTAINERS
    exported = []
    for name in containers:
        exported.append(await export_container(database, name, args.output))

    manifest = {
        "formatVersion": 1,
        "format": "jsonl+gzip",
        "database": args.database,
        "exportedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "containers": exported,
    }
    manifest_path = args.output / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    LOGGER.info("Export package written to %s", args.output)


def read_manifest(input_dir: Path) -> dict[str, Any]:
    manifest_path = input_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("formatVersion") != 1 or manifest.get("format") != "jsonl+gzip":
        raise ValueError("Unsupported Cosmos export format")
    return manifest


async def import_container(
    database: Any,
    input_dir: Path,
    entry: dict[str, Any],
    batch_size: int,
    concurrency: int,
    create_containers: bool,
) -> int:
    name = entry["name"]
    partition_key_paths = entry["partitionKeyPaths"]
    if len(partition_key_paths) != 1:
        raise ValueError(f"{name}: hierarchical partition keys are not supported")

    file_name = Path(entry["file"])
    if file_name.name != str(file_name):
        raise ValueError(f"{name}: invalid export file path")
    input_path = input_dir / file_name
    actual_hash = sha256_file(input_path)
    if actual_hash != entry["sha256"]:
        raise ValueError(f"{name}: SHA-256 mismatch")

    if create_containers:
        container = await database.create_container_if_not_exists(
            id=name,
            partition_key=PartitionKey(path=partition_key_paths[0]),
        )
    else:
        container = database.get_container_client(name)

    properties = await container.read()
    actual_paths = properties["partitionKey"]["paths"]
    if actual_paths != partition_key_paths:
        raise ValueError(
            f"{name}: destination partition key is {actual_paths}; expected {partition_key_paths}"
        )

    semaphore = asyncio.Semaphore(concurrency)

    async def upsert(document: dict[str, Any]) -> None:
        async with semaphore:
            await container.upsert_item(document)

    imported = 0
    batch: list[dict[str, Any]] = []
    with gzip.open(input_path, "rt", encoding="utf-8") as input_file:
        for line in input_file:
            if not line.strip():
                continue
            document = json.loads(line)
            if "id" not in document:
                raise ValueError(f"{name}: document without id")
            batch.append(document)
            if len(batch) >= batch_size:
                await asyncio.gather(*(upsert(document) for document in batch))
                imported += len(batch)
                batch.clear()
                LOGGER.info("%s: %d documents imported", name, imported)

    if batch:
        await asyncio.gather(*(upsert(document) for document in batch))
        imported += len(batch)

    if imported != entry["documents"]:
        raise ValueError(
            f"{name}: imported {imported} documents; expected {entry['documents']}"
        )
    LOGGER.info("%s complete: %d documents", name, imported)
    return imported


async def import_data(args: argparse.Namespace, database: Any) -> None:
    manifest = read_manifest(args.input)
    selected = set(args.container) if args.container else None
    entries = [
        entry
        for entry in manifest["containers"]
        if selected is None or entry["name"] in selected
    ]
    if selected is not None:
        missing = selected - {entry["name"] for entry in entries}
        if missing:
            raise ValueError(f"Containers not found in manifest: {sorted(missing)}")

    for entry in entries:
        await import_container(
            database,
            args.input,
            entry,
            args.batch_size,
            args.concurrency,
            args.create_containers,
        )


async def run(args: argparse.Namespace) -> None:
    async with DefaultAzureCredential() as credential:
        async with CosmosClient(args.endpoint, credential=credential) as client:
            if args.command == "export":
                database = client.get_database_client(args.database)
                await export_data(args, database)
            else:
                if args.create_containers:
                    database = await client.create_database_if_not_exists(
                        id=args.database
                    )
                else:
                    database = client.get_database_client(args.database)
                await import_data(args, database)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.getLogger("azure").setLevel(logging.WARNING)
    asyncio.run(run(parse_args()))


if __name__ == "__main__":
    main()