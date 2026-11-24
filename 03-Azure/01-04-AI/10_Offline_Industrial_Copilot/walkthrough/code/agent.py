"""Challenges 3 and 4: a local agent that calls tools.

run_agent(...)                   simple loop: one forced tool call, then the model answers (challenge 3)
run_agent(..., multi_step=True)  the model keeps calling tools until it calls final_answer (challenge 4)
"""
import json
import re
import sys

import fl
from tools import IMPLEMENTATIONS, TOOL_SCHEMAS

SYSTEM = (
    "You are a maintenance assistant for technicians at Contoso Precision Machining. "
    "Machine data and tickets are only available through your tools: never guess a machine reading. "
    "For procedures, limits, torque values, intervals and error codes, call search_sops and answer only from the "
    "excerpts. Keep every number and unit from the excerpts. Cite only SOP IDs that appear in the excerpts. "
    "When you call search_sops, copy the technician's whole question into it, word for word, so no topic is lost. "
    "If the excerpts do not contain the answer, say you could not find it in the SOPs. "
    "After you receive tool results, answer in at most three short sentences and then stop."
)
MULTI_STEP_SYSTEM = SYSTEM + " When you have everything you need, call final_answer."
FINAL_ANSWER = {"type": "function", "function": {
    "name": "final_answer",
    "description": "Give the technician the final answer once you have all the information you need.",
    "parameters": {"type": "object",
                   "properties": {"answer": {"type": "string", "description": "The answer. Keep all numbers and units."}},
                   "required": ["answer"]}}}

WRITE_TOOLS = {"create_maintenance_ticket"}
WRITE_INTENT = re.compile(r"\b(?:open|create|log|raise|file|make)\b[^.?!]{0,40}\bticket\b", re.I)
KNOWN_SOPS = {p.name.split("_")[0] for p in (fl.DATA / "sops").glob("*.md")}


def ask_technician(name, args):
    return input(f"  The assistant wants to run {name}({args}). Allow? [y/N] ").strip().lower() == "y"


SOP_REFERENCE = re.compile(r"SOP(?:\s+ID)?[\s:-]+[A-Z0-9][A-Z0-9-]*")
# "A ticket has been opened", "ticket MT-1001", "I created a ticket" - claims in the past tense, not SOP advice like "create a ticket".
TICKET_CLAIM = re.compile(
    r"ticket[^.]{0,60}\b(?:has|have|had|was|is)\s+(?:now\s+|successfully\s+)?(?:been\s+)?(?:opened|created|logged|raised)\b"
    r"|\b(?:I|we)(?:\s+have|'ve)?\s+(?:opened|created|logged|raised)\b[^.]{0,30}ticket"
    r"|\bMT-\d{3,}\b", re.I)


def scrub_citations(text):
    """A small model can invent a source (for example 'SOP ID 1024'). Drop every sentence that cites an SOP that does not exist."""
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    return " ".join(s for s in sentences if all(ref in KNOWN_SOPS for ref in SOP_REFERENCE.findall(s)))


def first_tool_call(reply):
    """Return (id, name, arguments) of the first tool call, or None.

    Some models write the call as text (for example <|tool_call|>[{...}]) instead of a structured call,
    so we parse that form too.
    """
    if reply.tool_calls:
        call = reply.tool_calls[0]
        return call.id, call.function.name, json.loads(call.function.arguments or "{}")
    match = re.search(r"<\|?tool_call\|?>\s*(\[.*\]|\{.*\})", reply.content or "", re.S)
    if match:
        try:
            data = json.loads(match.group(1))
            data = data[0] if isinstance(data, list) else data
            return "call_from_text", data["name"], data.get("arguments") or data.get("parameters") or {}
        except (ValueError, KeyError, IndexError):
            return None
    return None


def run_agent(client, model, question, extra_tools=None, approve=ask_technician, multi_step=False,
              router=None, shortlist=1, max_steps=6, verbose=True):
    """extra_tools is a list of (schema, function) pairs added to the two built-in tools.

    router (a ToolRouter) shortlists the tools shown to the model for this request. shortlist is how many.

    Tools that change something (WRITE_TOOLS) only run if approve() says yes. A small model can
    decide to create a ticket nobody asked for, so a person stays in the loop.
    """
    schemas = list(TOOL_SCHEMAS) + [s for s, _ in (extra_tools or [])] + ([FINAL_ANSWER] if multi_step else [])
    functions = dict(IMPLEMENTATIONS) | {s["function"]["name"]: f for s, f in (extra_tools or [])}
    # A tool that changes something is only offered when the technician asked for it. A model cannot invent a
    # ticket it is never offered, and a ticket request cannot be sent to the wrong tool.
    wants_write = bool(WRITE_INTENT.search(question))
    read_only = [s for s in schemas if s["function"]["name"] not in WRITE_TOOLS]
    write_only = [s for s in schemas if s["function"]["name"] in WRITE_TOOLS]
    first_step = write_only if wants_write else read_only
    if router is not None:
        # Tool shortlisting: show the model only the best-matching tools. A write tool is only shown if it is the best match.
        best = router.candidates(question)[:shortlist]
        if best and best[0] in WRITE_TOOLS:
            wants_write, first_step = True, [s for s in schemas if s["function"]["name"] == best[0]]
        else:
            first_step = [s for s in read_only if s["function"]["name"] in best] or read_only
    messages = [{"role": "system", "content": MULTI_STEP_SYSTEM if multi_step else SYSTEM},
                {"role": "user", "content": question}]
    sources = []

    def finish(text):
        text = scrub_citations(text or "")
        # No write tool ran in this branch, so any claim that a ticket was opened is made up.
        if TICKET_CLAIM.search(text):
            return "No ticket was created: the assistant did not call the ticket tool. Please ask again, for example: 'Open a high priority ticket for CNC-07: <problem>'."
        # Small models forget to cite, so the app attaches the SOPs it really retrieved.
        if sources and "not find" not in text.lower():
            text += "\n  Sources: " + "; ".join(sources)
        return text

    for step in range(max_steps):
        # Small models often describe a tool call instead of making one, so a call is mandatory.
        # In the simple loop only the first step is forced and the next step must answer in text.
        choice = "required" if (multi_step or step == 0) else "none"
        offered = first_step if step == 0 else (schemas if wants_write else read_only)
        reply = client.chat.completions.create(
            model=model, messages=messages, tools=offered, tool_choice=choice, temperature=0, max_tokens=500,
        ).choices[0].message
        call = first_tool_call(reply)
        if call is None:
            return finish(reply.content)
        call_id, name, args = call
        if name == "final_answer":
            return finish(args.get("answer", ""))
        if name not in functions:
            return finish(f"(the model asked for an unknown tool: {name})")
        if verbose:
            print(f"  -> {name}({args})")
        # One tool call at a time keeps the history valid and stops a model from inventing extra actions.
        messages.append({"role": "assistant", "content": None, "tool_calls": [
            {"id": call_id, "type": "function", "function": {"name": name, "arguments": json.dumps(args)}}]})
        if name in WRITE_TOOLS:
            # The app, not the model, reports what happened. A small model can claim a ticket exists when it never called the tool.
            if not approve(name, args):
                return "Cancelled: the technician did not approve, so nothing was changed."
            result = functions[name](**args)
            if "error" in result:
                return f"Nothing was changed: {result['error']}"
            return (f"Ticket {result['ticket_id']} created for {result['machine_id']} "
                    f"({result['priority']} priority): {result['summary']}")
        result = functions[name](**args)
        if isinstance(result, dict) and isinstance(result.get("excerpts"), list):
            sources += [s for s in (f"{e['sop']} rev {e['revision']} / {e['section']}" for e in result["excerpts"])
                        if s not in sources]
        messages.append({"role": "tool", "tool_call_id": call_id, "content": json.dumps(result)})
    return "(stopped: too many steps)"


if __name__ == "__main__":
    model = fl.load(sys.argv[2] if len(sys.argv) > 2 else "phi-4-mini")
    question = sys.argv[1] if len(sys.argv) > 1 else "What is the status of machine CNC-07?"
    print(run_agent(fl.client(), model, question))
