"""Challenge 5: train a fault classifier and export it to ONNX.

Run it locally (it takes a few seconds) or paste it into an Azure Machine Learning notebook.

  python train_fault_classifier.py [output_folder] [sensor_history.csv]

By default it writes an 'artifacts' folder next to this file and reads resources/data/sensor_history.csv.
"""
import csv
import json
import sys
from pathlib import Path

import numpy as np
from skl2onnx import to_onnx
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, confusion_matrix
from sklearn.model_selection import train_test_split

HERE = Path(__file__).resolve().parent
DEFAULT_CSV = next((p / "resources" / "data" / "sensor_history.csv" for p in HERE.parents
                    if (p / "resources" / "data").is_dir()), HERE / "sensor_history.csv")
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "artifacts"
CSV = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_CSV
FEATURES = ["vibration_mm_s", "temperature_c", "load_pct", "current_a", "hours_since_service"]
LABELS = ["normal", "bearing_wear", "overheating", "low_lubrication"]


def generate(rows_per_class=600, seed=42):
    rng = np.random.default_rng(seed)
    n = rows_per_class
    parts = []
    for label, (vib, temp, hours) in {
        "normal": ((2.5, 0.9), (60, 6), (0, 2500)),
        "bearing_wear": ((7.8, 1.6), (73, 6), (1200, 3500)),
        "overheating": ((3.4, 1.0), (92, 7), (500, 3500)),
        "low_lubrication": ((5.4, 0.8), (66, 5), (2000, 4200)),
    }.items():
        load = rng.uniform(30, 90, n)
        current = np.clip(load * 0.36 + rng.normal(0, 2, n) + (6 if label == "overheating" else 0), 1, 80)
        features = np.column_stack([
            np.clip(rng.normal(*vib, n), 0.2, 20),
            np.clip(rng.normal(*temp, n), 20, 130),
            load,
            current,
            rng.uniform(*hours, n),
        ]).round(1)
        parts.append(np.column_stack([features, np.full(n, LABELS.index(label))]))
    data = np.vstack(parts)
    rng.shuffle(data)
    return data


def write_csv(data):
    CSV.parent.mkdir(parents=True, exist_ok=True)
    with CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(FEATURES + ["label"])
        for row in data:
            w.writerow([*row[:-1], LABELS[int(row[-1])]])


def load_csv():
    with CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    x = np.array([[float(r[c]) for c in FEATURES] for r in rows], dtype=np.float32)
    y = np.array([LABELS.index(r["label"]) for r in rows])
    return x, y


if __name__ == "__main__":
    if not CSV.exists():
        write_csv(generate())
    x, y = load_csv()
    x_train, x_test, y_train, y_test = train_test_split(x, y, test_size=0.25, random_state=1, stratify=y)
    model = RandomForestClassifier(n_estimators=40, max_depth=6, random_state=1).fit(x_train, y_train)
    pred = model.predict(x_test)
    print(f"rows={len(x)} test accuracy={accuracy_score(y_test, pred):.3f}")
    print(LABELS)
    print(confusion_matrix(y_test, pred))

    OUT.mkdir(parents=True, exist_ok=True)
    onnx_model = to_onnx(model, x[:1], options={id(model): {"zipmap": False}}, target_opset=17)
    (OUT / "fault_classifier.onnx").write_bytes(onnx_model.SerializeToString())
    (OUT / "fault_labels.json").write_text(json.dumps({"features": FEATURES, "labels": LABELS}, indent=2))
    print("wrote", OUT / "fault_classifier.onnx", f"({(OUT / 'fault_classifier.onnx').stat().st_size // 1024} KB)")
