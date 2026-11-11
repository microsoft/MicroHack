# Challenge 5 - Train in the cloud, deploy at the edge

[Previous Challenge](challenge-04.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-06.md)

## Goal

Show that the edge agent can use a model that you **trained with cloud tooling** and that then runs locally, with no cloud dependency.

Your coach tells you which path to take. The result is the same.

## Actions

### Full path (60 minutes)

* In your Azure Machine Learning workspace (the name is on your lab page), create a small compute instance and open a notebook.
* Upload `resources/data/sensor_history.csv` and train a **fault classifier**: from the sensor readings it predicts `normal`, `bearing_wear`, `overheating` or `low_lubrication`.
* Export the model to **ONNX** and check that ONNX Runtime gives the same answers as your training library.
* Download the ONNX file to your device.
* Stop or delete the compute instance when you are done.

### Shortcut path (25 minutes)

* Read through the notebook `resources/shortcut/train_fault_classifier.ipynb` to see how the model was trained and exported. You do not need to run it.
* Use the ready-made `resources/shortcut/fault_classifier.onnx`.

### Both paths

* Run the ONNX model on your device with ONNX Runtime, **without** the training library. How long does one prediction take?
* Add a `predict_fault(machine_id)` tool to your agent. It reads the machine's readings and returns the predicted fault with its confidence.
* Ask the agent for the most likely fault of CNC-07 in **three different ways**. Does it call your classifier every time? Then make the choice of tool reliable. Measure it with the requests in `resources/data/eval/routing_eval.json`, and then add your own.
* Look at CNC-07, CMP-01 and PRESS-02. Which prediction would you trust, and which not?

## Success criteria

* The ONNX model runs on your device and does not call the cloud.
* The agent calls the model as a tool and uses the result in its answer.
* You can say how confident the classifier is for each of the three machines, and what a technician should do with a low-confidence result.

## Learning resources

* [Azure Machine Learning notebooks](https://learn.microsoft.com/azure/machine-learning/how-to-run-jupyter-notebooks)
* [ONNX Runtime](https://onnxruntime.ai/docs/)
* [Convert scikit-learn models to ONNX](https://onnx.ai/sklearn-onnx/)
