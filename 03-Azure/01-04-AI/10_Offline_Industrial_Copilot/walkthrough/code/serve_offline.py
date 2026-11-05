"""Start Foundry Local so that it does NOT need the internet to start (challenge 6).

The `foundry` service loads its model catalog from the internet every time it starts. If it is restarted while
the device is offline, it cannot find any model, even models that are already on the disk. This script starts the
service from the Foundry Local Python SDK instead, with a catalog that is never contacted. It finds the models
in your local cache and serves them on the same kind of OpenAI-compatible address.

  python serve_offline.py                        serves phi-4-mini and qwen3-embedding-0.6b (CPU variants) on port 5272
  python serve_offline.py phi-4-mini --port 5300
  python serve_offline.py --accelerate           use the GPU/NPU variants instead (see the note below)

In another terminal, point the lab code at it:

  set FOUNDRY_LOCAL_URL=http://127.0.0.1:5272/v1          (PowerShell: $env:FOUNDRY_LOCAL_URL = "http://127.0.0.1:5272/v1")

Download the models first, while you are online (challenge 1). Use `pip install foundry-local-sdk` before you disconnect.

Note on GPU and NPU (--accelerate): these model variants need an "execution provider". The NPU one is installed with
Foundry Local. The GPU one (WebGPU) is downloaded the first time you run a GPU model online and then kept in
~/.foundry/ep. The SDK tries to download it again at every start, which fails offline and leaves every GPU model
unloadable. This script therefore points the SDK at the copy on the disk (FOUNDRY_LOCAL_WEBGPU_EP_LIBRARY).
Run a GPU model once while online before you rely on this. The CPU variants need no provider.
"""
import argparse
import json
import os
import time
from pathlib import Path

from foundry_local_sdk import Configuration, FoundryLocalManager, LogLevel

SERVED = Path(os.environ.get("FOUNDRY_SERVED_MODELS", Path.home() / ".foundry" / "served_models.json"))
LOOPBACK_CATALOG = ("http://127.0.0.1:9", None)  # nothing listens here, so the catalog fails at once instead of timing out
WEBGPU_BUNDLES = Path.home() / ".foundry" / "ep" / "webgpu-ep" / "bundles"


def use_local_webgpu_provider():
    """Tell the SDK to use the WebGPU provider that is already on the disk.

    Without this the SDK tries to download the provider again every time it starts. Offline that fails, the provider is
    not registered, and every GPU model refuses to load (the SDK still says 'success'). It was downloaded the first time
    you ran a GPU model online. Returns the path that was used, or None.
    """
    found = sorted(WEBGPU_BUNDLES.glob("*/bin/onnxruntime_providers_webgpu.dll")) if WEBGPU_BUNDLES.exists() else []
    if found and not os.environ.get("FOUNDRY_LOCAL_WEBGPU_EP_LIBRARY"):
        os.environ["FOUNDRY_LOCAL_WEBGPU_EP_LIBRARY"] = str(found[-1])
    return os.environ.get("FOUNDRY_LOCAL_WEBGPU_EP_LIBRARY")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("aliases", nargs="*", default=["phi-4-mini", "qwen3-embedding-0.6b"])
    ap.add_argument("--port", type=int, default=5272)
    ap.add_argument("--cache", default=os.environ.get("FOUNDRY_CACHE", str(Path.home() / ".foundry" / "cache" / "models")))
    ap.add_argument("--accelerate", action="store_true", help="use the GPU/NPU variants (they must have been used once while online)")
    args = ap.parse_args()

    if args.accelerate:
        provider = use_local_webgpu_provider()
        print(f"WebGPU provider: {provider or 'none on this machine (GPU variants will not load; NPU and CPU still work)'}")

    config = Configuration(
        app_name="offline-copilot", model_cache_dir=args.cache, log_level=LogLevel.WARNING,
        catalog_urls=[LOOPBACK_CATALOG], web=Configuration.WebService(urls=f"http://127.0.0.1:{args.port}"))
    FoundryLocalManager.initialize(config)
    manager = FoundryLocalManager.instance

    if args.accelerate:
        try:
            result = manager.download_and_register_eps(progress_callback=lambda *a: None)
            print(f"execution providers registered: {result.registered_eps}")
        except Exception as e:  # carry on: the CPU variants need no provider
            print(f"Could not register GPU/NPU providers ({str(e)[:80]}). Using CPU variants.")

    cached = manager.catalog.get_cached_models()
    served = {}
    for alias in args.aliases:
        variants = [v for v in cached if v.alias == alias]
        # try the preferred hardware first, then fall back to the other
        variants.sort(key=lambda v: 0 if (("cpu" in v.id.lower()) != args.accelerate) else 1)
        for variant in variants:
            try:
                variant.load()
                served[alias] = variant.id
                print(f"loaded {alias:<24} -> {variant.id}")
                break
            except Exception as e:
                print(f"  could not load {variant.id}: {str(e)[:100]}")
        else:
            raise SystemExit(f"'{alias}' is not in the local cache ({args.cache}). Download it first: foundry model download {alias}")

    manager.start_web_service()
    SERVED.parent.mkdir(parents=True, exist_ok=True)
    SERVED.write_text(json.dumps(served, indent=2), encoding="utf-8")
    url = manager.urls[0].rstrip("/") + "/v1"
    print(f"\nServing on {url}\nIn another terminal:  $env:FOUNDRY_LOCAL_URL = \"{url}\"\nPress Ctrl+C to stop.")
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass
    finally:
        manager.stop_web_service()
        SERVED.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
