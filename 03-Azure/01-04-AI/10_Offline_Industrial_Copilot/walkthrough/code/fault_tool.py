"""Challenge 5: the cloud-trained ONNX fault classifier, exposed as an agent tool."""
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort

import fl
from tools import get_machine_status

# Use your own trained model if you made one (challenge 5, full path), otherwise the shortcut artifact.
_own = Path(__file__).resolve().parent / "artifacts"
ARTIFACTS = _own if (_own / "fault_classifier.onnx").exists() else fl.DATA.parent / "shortcut"
_meta = json.loads((ARTIFACTS / "fault_labels.json").read_text(encoding="utf-8"))
# CPU only: the model is tiny, so it runs in milliseconds with no GPU, no NPU and no network.
_session = ort.InferenceSession(str(ARTIFACTS / "fault_classifier.onnx"), providers=["CPUExecutionProvider"])


def predict_fault(machine_id: str) -> dict:
    machine = get_machine_status(machine_id)
    if "error" in machine:
        return machine
    features = np.array([[machine[f] for f in _meta["features"]]], dtype=np.float32)
    label_idx, probabilities = _session.run(None, {_session.get_inputs()[0].name: features})
    ranked = sorted(zip(_meta["labels"], probabilities[0].tolist()), key=lambda x: -x[1])
    return {
        "machine_id": machine["id"],
        "predicted_fault": _meta["labels"][int(label_idx[0])],
        "confidence": round(ranked[0][1], 2),
        "other_candidates": [{"fault": n, "probability": round(p, 2)} for n, p in ranked[1:3] if p >= 0.05],
    }


SCHEMA = {"type": "function", "function": {
    "name": "predict_fault",
    "description": "Predict the most likely fault type of a machine from its current sensor readings, "
                   "using a trained classifier. Use this when a machine has a warning or fault.",
    "parameters": {"type": "object",
                   "properties": {"machine_id": {"type": "string", "description": "Machine ID such as CNC-07"}},
                   "required": ["machine_id"]}}}
