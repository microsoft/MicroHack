# Challenge 4 - Agentic retrieval over local knowledge

[Previous Challenge](challenge-03.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-05.md)

## Goal

Ground the agent in the plant's SOPs, with the **agent deciding when and what to retrieve**, and cite the source of every answer.

## Actions

* Download the embedding model `qwen3-embedding-0.6b` and load it next to your chat model. Do both fit on your device at the same time?
* Cut the SOPs in `resources/data/sops` into chunks. Think about what a good chunk is: where do you cut, and what must travel with every chunk so the answer can cite it?
* Create an embedding for every chunk and keep them in a simple local store (a file and NumPy are enough).
* Give the agent a **`search_sops` tool**. The agent decides when to call it.
* Make every grounded answer show **which SOP** it came from. Can you trust the model to do this on its own?
* Make sure the agent says *"I could not find this in the SOPs"* when the answer is not there, for example for *"What is on the cafeteria menu on Friday?"*
* Make a question with **two topics** work, for example: *"What torque do I use for the spindle bearing bolts, and what must I do before I start work on the spindle?"*
* Evaluate your agent with `resources/data/eval/retrieval_eval.json` and `compound_eval.json`. Report: correct facts, correct source, and correct refusals. Then change one thing and see if a number improves.

## Success criteria

* *"At what vibration level must a CNC spindle be stopped?"* is answered from SOP-CNC-001 **with a citation**.
* The agent retrieves for each topic when a question has more than one topic.
* A question that is not in the SOPs gets a refusal and not an invented answer.
* You can report your results on the evaluation questions, and you changed one thing and measured the effect.

## Learning resources

* [What is Foundry Local?](https://learn.microsoft.com/azure/foundry-local/what-is-foundry-local)
* [Foundry Local CLI reference](https://learn.microsoft.com/azure/foundry-local/reference/reference-cli)
