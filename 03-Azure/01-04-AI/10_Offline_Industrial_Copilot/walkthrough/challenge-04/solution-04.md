# Walkthrough Challenge 4 - Agentic retrieval over local knowledge

[Previous Challenge Solution](../challenge-03/solution-03.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-05/solution-05.md)

Duration: 75 minutes

## Prerequisites

Please ensure that you successfully completed [Challenge 3](../../challenges/challenge-03.md) before continuing with this challenge.

### **Task 1: Load an embedding model next to the chat model**

```powershell
foundry model download qwen3-embedding-0.6b
```

`fl.load("qwen3-embedding-0.6b")` loads it. It is 515 MB, produces vectors with 1,024 numbers, and runs on the GPU while `phi-4-mini` runs next to it. Embedding the 25 chunks of the SOPs takes a few seconds.

### **Task 2: Chunk the SOPs**

Every SOP has the same shape: a header with the SOP ID and the revision, then sections starting with `##`. [retrieval.py](../code/retrieval.py) makes **one chunk per section**, and puts the SOP title and header in front of every chunk:

```python
"text": f"{title} ({sop_id})\n{header}\n\n## {section}\n{body}"
```

💡 Why the header travels with the chunk: a section called *"Routine"* means nothing alone. With the header it says *"SOP-CMP-001, air compressor"*, so retrieval can match the machine, and the answer can cite the SOP and its revision.

### **Task 3: Embed and store**

```python
vectors = embed(client, embed_model, [c["text"] for c in chunks])   # normalised
INDEX.write_text(json.dumps({"chunks": chunks, "vectors": vectors.tolist()}))
```

25 vectors do not need a vector database. A JSON file and NumPy dot products are enough. Because the vectors are normalised, `vectors @ query` is the cosine similarity.

### **Task 4: Retrieval as a tool**

```python
def search_sops(query: str) -> dict:
    queries = decompose(client, chat_model, query)       # one query per topic
    for q in queries:
        for chunk, score in retrieve(client, embed_model, chunks, vectors, q, k=3):
            if score >= 0.35: ...                          # keep it, once
    return {"queries": queries, "excerpts": excerpts or "No relevant SOP found."}
```

The agent from challenge 3 gets this as a third tool. It **decides** whether a question needs the SOPs: *"What is the status of CNC-07?"* calls the machine tool, *"At what vibration level must a CNC spindle be stopped?"* calls `search_sops`.

- **`min_score=0.35`** is what makes the agent refuse. A question about the cafeteria menu finds nothing above the threshold.
- **Compound questions.** A small model rewrites *"What torque do I use for the bolts, and what must I do before I start?"* into one short query and loses a topic. `decompose` asks the model, in plain text, to split the question into topics. Each topic gets its own search, and the excerpts are merged. The tool description and the system prompt tell the agent to pass the technician's whole question.

### **Task 5: Citations**

Do not trust the small model to cite. In the test it named the source in only 3 of 13 answers. The app attaches the SOPs it really retrieved, and removes sentences that cite an SOP that does not exist:

```text
Stop the machine if the vibration level reaches 7.1 mm/s RMS or higher.
  Sources: SOP-CNC-001 rev C / Vibration limits; SOP-CNC-001 rev C / Records
```

`scrub_citations` in [agent.py](../code/agent.py) matters: without it `phi-4-mini` ends answers with *"Please refer to SOP ID 1024 for maintenance procedures"*, an SOP that does not exist.

### **Task 6: Evaluate**

```powershell
python evaluate_retrieval.py          # always retrieve, then answer
python evaluate_retrieval.py agent    # the agent decides
python evaluate_compound.py           # questions with two topics
```

Reference results with `phi-4-mini` (13 answerable questions and 2 that are not in the SOPs):

| | Retrieval finds the right SOP | Answer has the expected facts | Right SOP cited | Refuses what it cannot answer |
|---|---|---|---|---|
| Always retrieve | 13/13 | 12/13 | 11/13 | 2/2 |
| Agent with `search_sops` | n/a | 12/13 | 12/13 | 2/2 |

Questions with two topics (3 questions, 2 runs each): both SOPs found in 6 of 6 runs, all expected facts in 4 of 6, and two runs in six did not split the question into two topics. The answers are not identical between runs, so a difference of one is noise.

💡 Retrieval is rarely the problem here: the right SOP is found every time. The misses are in what the small model **does with** the excerpts, for example it quotes the trip temperature (110 °C) instead of the alarm temperature (100 °C). That is the kind of thing a team can improve.

### **Task 7: Change one thing and measure it**

Ideas that teams try, and what to watch:

- **Chunk size:** smaller chunks (one step per chunk) improve precision but can lose context.
- **`k` and `min_score`:** more excerpts help recall and hurt precision. A higher threshold refuses more often, also when it should not.
- **The prompt:** *"quote the number from the excerpt"* often fixes the wrong-number misses.
- **A bigger chat model:** try another model from challenge 2 and see if the facts improve.

You successfully completed challenge 4! 🚀🚀🚀

## Coach notes

- **Always-retrieve versus agentic retrieval.** The two rows in the table are the discussion: always retrieving is simpler, a bit better here, and cannot skip the search for a machine status. Agentic retrieval lets one agent handle both kinds of question and choose, at the cost of one more model decision that can go wrong. For a single-purpose Q&A bot, always retrieve. For a copilot that also acts, let the agent decide.
- **Keep the document set small.** Embedding must finish in seconds on a CPU.
- **Stretch goal:** combine tools in one answer: retrieve the SOP, check the machine status and create a ticket in one turn. The reference code has a `multi_step=True` mode for this, where every step must call a tool and the model ends with a `final_answer` tool. **It is unreliable with `phi-4-mini`**: in the test it picked the wrong tool for a ticket request, dropped the key number from the answer, and once repeated one sentence until it ran out of tokens. Use it to show why the simple loop is the default, or to try a bigger model.
- The first call of every tool is slow (several seconds) because the model has to be loaded and warmed up. Warm the models up before the demo.
