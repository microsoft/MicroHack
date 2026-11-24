"""Challenge 1: your first call to a model that runs on your own machine."""
import time

import fl

model = fl.load("phi-4-mini")
client = fl.client()

start = time.perf_counter()
reply = client.chat.completions.create(
    model=model,
    messages=[{"role": "user", "content": "In one sentence: what does a technician check first when a CNC spindle vibrates?"}],
    max_tokens=80,
)
print(reply.choices[0].message.content)
print(f"\nAnswered in {time.perf_counter() - start:.1f} s by {model} on this machine.")
