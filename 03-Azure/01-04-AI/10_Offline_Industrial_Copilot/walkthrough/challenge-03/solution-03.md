# Walkthrough Challenge 3 - Build your first local agent

[Previous Challenge Solution](../challenge-02/solution-02.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-04/solution-04.md)

Duration: 60 minutes

## Prerequisites

Please ensure that you successfully completed [Challenge 2](../../challenges/challenge-02.md) before continuing with this challenge. The reference code uses `phi-4-mini`.

### **Task 1: Write the tools**

[tools.py](../code/tools.py) has two plain Python functions and their JSON schemas:

```python
def get_machine_status(machine_id: str) -> dict:
    machines = json.loads((DATA / "machines.json").read_text(encoding="utf-8"))["machines"]
    for m in machines:
        if m["id"].lower() == machine_id.strip().lower():
            return m
    return {"error": f"Unknown machine '{machine_id}'", "known_machines": [m["id"] for m in machines]}


def create_maintenance_ticket(machine_id: str, summary: str, priority: str) -> dict:
    if priority not in ("low", "medium", "high"):
        return {"error": "priority must be low, medium or high"}
    ...  # append one JSON line to tickets.jsonl and return the ticket
```

💡 The tools **validate their own input** and return an error the model can read. A small model sometimes sends a machine ID that does not exist (for a question about the cafeteria it sent `cafeteria_menu`). A tool that returns `{"error": ...}` lets the agent recover. A tool that raises an exception ends the conversation.

### **Task 2: The system prompt**

```text
You are a maintenance assistant for technicians at Contoso Precision Machining.
Machine data and tickets are only available through your tools: never guess a machine reading.
After you receive tool results, answer in at most three short sentences and then stop.
```

Short and specific works best with small models. "Never guess" matters: without it, `phi-4-mini` answers *"I do not have real-time data"* instead of calling the tool.

### **Task 3: The tool-call loop**

The loop in [agent.py](../code/agent.py) does this:

1. Send the conversation and the tool schemas to the model.
2. If the model asks for a tool, run it and add the result to the conversation.
3. Send the conversation again. Stop when the model answers in text.

```python
choice = "required" if step == 0 else "none"
reply = client.chat.completions.create(
    model=model, messages=messages, tools=schemas, tool_choice=choice, temperature=0, max_tokens=500,
).choices[0].message
```

Three details make it work with a small model:

- **The first step uses `tool_choice="required"`.** With `"auto"` the model usually describes the tool call in words (challenge 2: 1 of 8). With `"required"` it makes a proper call (7 of 8). The next step uses `"none"`, so the model has to write the answer.
- **One tool call per step.** Models like `qwen3-1.7b` call several tools at once, including tools nobody asked for. The loop runs the first call and ignores the rest.
- **A step limit.** `max_steps` guarantees that the loop ends.

### **Task 4: Test it**

```powershell
python agent.py "What is the status of machine CNC-07?"
```

```text
  -> get_machine_status({'machine_id': 'CNC-07'})
The CNC-07 machine is currently in a FAULT state due to high spindle vibration (E-SPN-214).
The vibration measurement is 9.4 mm/s and the temperature is 78.0°C. Service is needed.
```

A question that needs no tool, such as *"Why is the sky blue?"*, still gets a forced tool call in this simple loop. The model then picks the closest tool or answers that it has no data. That is a real limit of `"required"`, and challenge 4 shows one way around it.

### **Task 5: The confirmation step**

Writing a ticket changes something, so three things protect the technician. All three are in [agent.py](../code/agent.py).

**1. The write tool is only offered when the technician asked for it.** A model cannot invent a ticket it is never offered:

```python
WRITE_INTENT = re.compile(r"\b(?:open|create|log|raise|file|make)\b[^.?!]{0,40}\bticket\b", re.I)
wants_write = bool(WRITE_INTENT.search(question))
offered = write_only if (wants_write and step == 0) else (schemas if wants_write else read_only)
```

A ticket request also always reaches the ticket tool, because it is the only tool offered in that step. Without this rule the same request was sent to `search_sops` instead, in 3 of 3 runs on the laptop and also on the CPU VM.

**2. A person must approve it:**

```python
if not approve(name, args):
    return "Cancelled: the technician did not approve, so nothing was changed."
```

**3. The app reports the result, not the model.** After the ticket tool runs, the app builds the confirmation from the tool result:

```text
  The assistant wants to run create_maintenance_ticket({'machine_id': 'CNC-07', 'priority': 'high', ...}). Allow? [y/N] y
Ticket MT-1001 created for CNC-07 (high priority): Spindle vibration above the stop limit
```

💥 **Why the model does not write the confirmation.** In a test where the ticket tool was never called, `phi-4-mini` answered *"A high-priority ticket has been opened for CNC-07"*. No ticket existed. An agent that tells a technician that work is logged when it is not is worse than an agent that fails. So the app writes the confirmation from the tool result, and `TICKET_CLAIM` in `agent.py` replaces any answer that claims a ticket exists when no ticket tool ran with an honest *"No ticket was created"*.

💡 This is not only for show. In the model comparison, `qwen3-1.7b` created a ticket with an invented summary for a plain status question. **A person in the loop, plus an app that decides when a write is allowed and reports what really happened, is what makes a small model safe enough to give write access.**

You successfully completed challenge 3! 🚀🚀🚀

## Coach notes

- If a team's model handles tool calls badly, send it back to [challenge 2](../../challenges/challenge-02.md): switch to a model that passes more tool cases, or use `tool_choice="required"`.
- `phi-4-mini` sometimes writes the call as text, for example `<|tool_call|>[{...}]`. The loop in challenge 4 parses that form as well.
- Give teams that are new to function calling the loop skeleton in Task 3 and let them write the tools themselves.
- **Tool choice is fragile.** Which tool the model picks first depends on the wording of the request, on the variant of the model (GPU, NPU or CPU) and, in our runs, even on the day. With all four tools shown, `phi-4-mini` chose the right first tool for only 14 of 23 held-out requests and never chose the fault classifier (0 of 5). [Challenge 5](../challenge-05/solution-05.md) adds a router that shortlists the tool and takes this to 23 of 23. [check_routing.py](../code/check_routing.py) measures it, on any device type you will use.
- **Stretch:** log every tool call and its arguments to a file, so a technician can see afterwards what the agent did.
