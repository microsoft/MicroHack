"""Tool shortlisting for the copilot.

A small model picks the wrong tool more often the more tools it is shown. So before the model sees a request,
we match the request against a short "card" of every tool with the embedding model that is already loaded for the
SOP search, and only show the model the best matches. (This is the same idea as retrieval over documents, applied
to tools. Research on tool retrieval reports large gains in tool-selection accuracy for this reason.)
"""
import re

import retrieval

# What each tool is for, in plain words, plus a few example requests. Examples matter most for a small embedding model.
CARDS = {
    "get_machine_status": (
        "Look up the live status and current sensor readings of one machine: running or stopped, temperature, "
        "vibration, load, current, error code.\n"
        "How is CNC-03 doing? Read me the temperature of PRESS-02. Is the lathe LATHE-05 online? "
        "What is the current load on ROB-04?"),
    "predict_fault": (
        "Predict or diagnose the most likely fault of one machine with the trained fault classification model: "
        "bearing wear, overheating, low lubrication.\n"
        "Predict what is going to fail on CNC-07. Classify the fault state of CMP-01. "
        "What is wrong with LATHE-05 according to the trained model? Run the diagnosis for PRESS-02."),
    "search_sops": (
        "Search the maintenance procedures (SOPs): limits, torque values, intervals, error codes, safety rules, "
        "how to do a task. General questions that name no machine.\n"
        "What is the torque for the gearbox cover? How do I replace the filter? Explain error code E-XYZ-001. "
        "What is the safety rule for working on a press? What does the procedure say? "
        "ROB-04 reports error E-WLD-120, what is the procedure to fix it?"),
    "create_maintenance_ticket": (
        "Open, create or log a maintenance ticket, work order or service request for a machine.\n"
        "Open a ticket for CNC-03. Create a maintenance request for ROB-04. Log this problem as a ticket. "
        "Write up a work order for the lathe."),
}
QUERY_PREFIX = "Instruct: Given a technician's request, find the tool that should handle it\nQuery: "
MACHINE_ID = re.compile(r"\b[A-Z]{2,6}-\d{2}\b", re.I)  # CNC-07, PRESS-02 ... (error codes like E-SPN-214 do not match)
NEEDS_MACHINE_ID = {"get_machine_status", "predict_fault", "create_maintenance_ticket"}


class ToolRouter:
    def __init__(self, client, embed_model, names=None, prefix=QUERY_PREFIX):
        self.client, self.embed_model, self.prefix = client, embed_model, prefix
        self.names = list(names or CARDS)
        self.vectors = retrieval.embed(client, embed_model, [CARDS[n] for n in self.names])

    def rank(self, request):
        q = retrieval.embed(self.client, self.embed_model, [self.prefix + request])[0]
        scores = self.vectors @ q
        return sorted(zip(self.names, scores.tolist()), key=lambda x: -x[1])

    def candidates(self, request):
        """Tool names for this request, best first. A tool that needs a machine ID is dropped when the request names none."""
        ranked = self.rank(request)
        if not MACHINE_ID.search(request):
            ranked = [(n, s) for n, s in ranked if n not in NEEDS_MACHINE_ID]
        return [n for n, _ in ranked]
