---
title: Tire Building Machine
machineType: tire_building_machine
domain: tire-manufacturing
summary: Troubleshooting and maintenance guidance derived from factory KB
last_reviewed: 2025-12-29
---

# Tire Building Machine

This page summarizes common issues, diagnostic steps, and fixes for tire building machines.

## Operating Thresholds

- Drum vibration: normal ≤ 3.0 mm/s (excessive if above 3.0 mm/s)
- Ply tension: normal ≤ 230 N (excessive if above 230 N)

---

## Building Drum Vibration (Priority: High)

- Fault Type: building_drum_vibration
- Symptoms: Vibration above 3.0 mm/s; uneven tire build; material placement errors; unusual noise
- Likely Causes: Bearing wear on drum shaft; drum imbalance; loose mounting bolts; misaligned drive components; worn coupling
- Diagnostics:
  - Perform vibration analysis on drum bearings
  - Check drum balance with dial indicator
  - Inspect all mounting hardware
  - Verify drive alignment
  - Examine coupling for wear
- Corrective Actions:
  - Replace drum shaft bearings
  - Balance drum assembly
  - Tighten mounting bolts to specification
  - Realign servo motor and drum shaft
  - Replace worn coupling
- Estimated Repair Time: 4–8 hours
- Impact: Tire build quality; uniformity issues

## Ply Tension Excessive (Priority: Medium)

- Fault Type: ply_tension_excessive
- Symptoms: Tension exceeds 230 N; material stretching; inconsistent tire dimensions; servo alarms
- Likely Causes: Tension roller misalignment; servo motor tuning issues; material property variation; dancer arm malfunction; load cell calibration drift
- Diagnostics:
  - Check tension roller alignment
  - Review servo motor parameters
  - Verify incoming material specifications
  - Test dancer arm movement
  - Calibrate tension load cells
- Corrective Actions:
  - Align tension rollers properly
  - Retune servo motor PID parameters
  - Adjust for material batch variations
  - Repair or replace dancer arm mechanism
  - Recalibrate tension measurement system
- Estimated Repair Time: 2–4 hours
- Impact: Tire dimensional accuracy; structural integrity

---

## Notes

- Keep a maintenance log for alignment checks and PID tune changes.
- Calibrate load cells routinely; verify after any mechanical interventions.
