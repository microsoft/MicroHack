"""Challenge 6 (optional): compare local latency with a cloud model.

Set these environment variables first (any OpenAI-compatible cloud endpoint works):
  CLOUD_BASE_URL   for example https://<resource>.openai.azure.com/openai/v1
  CLOUD_API_KEY    the key for that endpoint
  CLOUD_MODEL      the deployment name, for example gpt-4.1-mini
"""
import os
import statistics
import sys
import time

from openai import OpenAI

import fl

QUESTIONS = [
    "In one sentence, what causes spindle bearing wear?",
    "In one sentence, why must a hydraulic press be depressurised before maintenance?",
    "In one sentence, what is lockout/tagout?",
]


def time_calls(client, model, runs=3):
    samples = []
    for _ in range(runs):
        for q in QUESTIONS:
            start = time.perf_counter()
            client.chat.completions.create(model=model, max_tokens=60, messages=[{"role": "user", "content": q}])
            samples.append(time.perf_counter() - start)
    return statistics.median(samples), max(samples)


if __name__ == "__main__":
    local_median, local_max = time_calls(fl.client(), fl.load("phi-4-mini"))
    print(f"local  median {local_median:.2f} s   worst {local_max:.2f} s")
    missing = [v for v in ("CLOUD_BASE_URL", "CLOUD_API_KEY", "CLOUD_MODEL") if not os.environ.get(v)]
    if missing:
        sys.exit(f"Cloud comparison skipped. Set: {', '.join(missing)}")
    cloud = OpenAI(base_url=os.environ["CLOUD_BASE_URL"], api_key=os.environ["CLOUD_API_KEY"])
    cloud_median, cloud_max = time_calls(cloud, os.environ["CLOUD_MODEL"])
    print(f"cloud  median {cloud_median:.2f} s   worst {cloud_max:.2f} s")
