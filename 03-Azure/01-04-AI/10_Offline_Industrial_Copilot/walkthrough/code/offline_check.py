"""Challenge 6: check that the copilot really works without the internet."""
import json
import socket
import time
import urllib.parse

import fl


def internet_reachable(host="1.1.1.1", port=443, timeout=3):
    try:
        socket.create_connection((host, port), timeout=timeout).close()
        return True
    except OSError:
        return False


def main():
    url = fl.base_url()
    host = urllib.parse.urlparse(url).hostname
    print(f"Model service : {url}")
    print(f"Runs locally  : {'yes' if host in ('127.0.0.1', 'localhost', '::1') else 'NO - this is not a loopback address'}")
    online = internet_reachable()
    print(f"Internet      : {'REACHABLE - disconnect (or block) the network and run this again' if online else 'not reachable (offline)'}")

    client = fl.client()
    model = fl.load("phi-4-mini")
    timings = []
    for question in ("In one sentence, what causes spindle bearing wear?", "Say OK."):
        start = time.perf_counter()
        client.chat.completions.create(model=model, max_tokens=40, messages=[{"role": "user", "content": question}])
        timings.append(round(time.perf_counter() - start, 2))
    print(f"Local answers : {timings} s")
    print(json.dumps({"offline": not online, "local_latency_s": timings}))


if __name__ == "__main__":
    main()
