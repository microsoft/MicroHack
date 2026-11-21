"""Challenge 4: agentic retrieval over the local SOPs, with citations."""
import json
import re
import sys
from pathlib import Path

import numpy as np

import fl

EMBED_MODEL = "qwen3-embedding-0.6b"
CHAT_MODEL = "phi-4-mini"
INDEX = Path(__file__).resolve().parent / "sop_index.json"

ANSWER_SYSTEM = (
    "You answer maintenance questions using ONLY the numbered SOP excerpts provided. "
    "Cite the SOP ID in square brackets after each fact, for example [SOP-CNC-001]. "
    'If the excerpts do not contain the answer, reply exactly: "I could not find this in the SOPs."'
)


def chunk_sops():
    """One chunk per section (## heading). The SOP ID and revision travel with every chunk."""
    chunks = []
    for path in sorted((fl.DATA / "sops").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        sop_id = path.name.split("_")[0]
        revision = re.search(r"\*\*Revision:\*\*\s*(.+)", text)
        header = text.split("\n## ")[0]
        for section in text.split("\n## ")[1:]:
            title, _, body = section.partition("\n")
            chunks.append({
                "sop": sop_id, "revision": revision.group(1).split()[0] if revision else "?",
                "section": title.strip(),
                # Prefixing the header makes the chunk self-contained, so retrieval can match the machine and error code.
                "text": f"{header.splitlines()[0]} ({sop_id})\n{header.split(chr(10), 1)[1].strip()}\n\n## {title}\n{body}".strip(),
            })
    return chunks


def embed(client, model, texts, batch=16):
    out = []
    for i in range(0, len(texts), batch):
        out += [d.embedding for d in client.embeddings.create(model=model, input=texts[i:i + batch]).data]
    v = np.array(out, dtype=np.float32)
    return v / np.linalg.norm(v, axis=1, keepdims=True)


def build_index(client, embed_model):
    chunks = chunk_sops()
    vectors = embed(client, embed_model, [c["text"] for c in chunks])
    INDEX.write_text(json.dumps({"chunks": chunks, "vectors": vectors.tolist()}), encoding="utf-8")
    return chunks, vectors


def load_index():
    data = json.loads(INDEX.read_text(encoding="utf-8"))
    return data["chunks"], np.array(data["vectors"], dtype=np.float32)


def retrieve(client, embed_model, chunks, vectors, question, k=3):
    q = embed(client, embed_model, [question])[0]
    scores = vectors @ q
    top = np.argsort(-scores)[:k]
    return [(chunks[i], float(scores[i])) for i in top]


def decompose(client, chat_model, question):
    """Split a compound question into one search query per topic. Small models do this plain-text task well."""
    reply = client.chat.completions.create(
        model=chat_model, temperature=0, max_tokens=120,
        messages=[{"role": "system", "content":
                   "Split the question into separate search queries, one per topic. "
                   'Reply with only a JSON list of short strings, for example ["torque for bolts", "lockout steps"]. '
                   "If the question has one topic, reply with a list of one string."},
                  {"role": "user", "content": question}],
    ).choices[0].message.content or ""
    match = re.search(r"\[.*\]", reply, re.S)
    try:
        queries = [q for q in json.loads(match.group(0)) if isinstance(q, str) and q.strip()] if match else []
    except ValueError:
        queries = []
    return queries[:3] or [question]


def search_tool(client, chat_model, embed_model, chunks, vectors, k_per_topic=3):
    """Wrap retrieval as an agent tool. A compound query is split into topics, and every topic is searched."""
    def search_sops(query: str) -> dict:
        queries = decompose(client, chat_model, query)
        excerpts, seen = [], set()
        for q in queries:
            for c, s in retrieve(client, embed_model, chunks, vectors, q, k_per_topic):
                key = (c["sop"], c["section"])
                if s >= 0.35 and key not in seen:
                    seen.add(key)
                    excerpts.append({"sop": c["sop"], "revision": c["revision"], "section": c["section"], "text": c["text"]})
        return {"queries": queries, "excerpts": excerpts or "No relevant SOP found."}

    schema = {"type": "function", "function": {
        "name": "search_sops",
        "description": "Search the maintenance SOPs (procedures, limits, torque values, intervals, error codes, "
                       "safety rules). It splits a question with several topics for you.",
        "parameters": {"type": "object",
                       "properties": {"query": {"type": "string", "description":
                                               "The technician's full question, copied word for word with every topic in it"}},
                       "required": ["query"]}}}
    return schema, search_sops


def answer(client, chat_model, embed_model, chunks, vectors, question, k=3, min_score=0.35):
    hits = [(c, s) for c, s in retrieve(client, embed_model, chunks, vectors, question, k) if s >= min_score]
    if not hits:
        return "I could not find this in the SOPs.", []
    context = "\n\n".join(f"[{c['sop']} rev {c['revision']} / {c['section']}]\n{c['text']}" for c, _ in hits)
    reply = client.chat.completions.create(
        model=chat_model, temperature=0, max_tokens=250,
        messages=[{"role": "system", "content": ANSWER_SYSTEM},
                  {"role": "user", "content": f"SOP excerpts:\n{context}\n\nQuestion: {question}"}],
    ).choices[0].message.content
    return reply.strip(), [(c["sop"], c["section"], round(s, 2)) for c, s in hits]


if __name__ == "__main__":
    client = fl.client()
    embed_model = fl.load(EMBED_MODEL)
    chat_model = fl.load(CHAT_MODEL)
    if not INDEX.exists():
        chunks, vectors = build_index(client, embed_model)
        print(f"Indexed {len(chunks)} chunks.")
    else:
        chunks, vectors = load_index()
    question = " ".join(sys.argv[1:]) or "At what vibration level must a CNC spindle be stopped?"
    text, sources = answer(client, chat_model, embed_model, chunks, vectors, question)
    print(text)
    print("Sources:", sources)
