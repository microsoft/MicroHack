---
title: Tire Uniformity Machine
machineType: tire_uniformity_machine
domain: tire-manufacturing
summary: Troubleshooting and maintenance guidance derived from factory KB
last_reviewed: 2025-12-29
---

# Tire Uniformity Machine

This page summarizes common issues, diagnostic steps, and fixes for tire uniformity testing.

## Operating Thresholds

- RFV (Radial Force Variation): target ≤ 100 N (high if exceeds 100 N)

## High Radial Force Variation (Priority: High)

- Fault Type: high_radial_force_variation
- Symptoms: RFV exceeds 100 N; tire vibration concerns; customer complaints; failed quality tests
- Likely Causes: Building process inconsistency; curing press issues; material non-uniformity; mold damage; green tire storage conditions
- Diagnostics:
  - Analyze RFV waveform for patterns
  - Trace tire back to building machine
  - Review curing press data for the tire
  - Inspect mold condition
  - Check material lot numbers
- Corrective Actions:
  - Adjust building machine parameters
  - Service or repair curing press
  - Quarantine affected material lots
  - Repair or replace damaged mold
  - Improve green tire storage practices
- Estimated Time: 1–2 hours analysis + upstream fixes
- Impact: Customer satisfaction; ride quality

## Load Cell Drift (Priority: Medium)

- Fault Type: load_cell_drift
- Symptoms: Inconsistent measurements; calibration check failures; trending data shift
- Likely Causes: Load cell aging; temperature variations; mechanical binding; electrical noise interference; previous mechanical shock
- Diagnostics:
  - Run master tire calibration check
  - Verify environmental temperature stability
  - Check for mechanical binding in load frame
  - Test signal cables for noise
  - Review maintenance history for impacts
- Corrective Actions:
  - Perform full system recalibration
  - Replace load cells if out of specification
  - Improve temperature control
  - Free up mechanical bindings
  - Replace damaged cables; add shielding
- Estimated Repair Time: 2–4 hours
- Impact: Measurement accuracy; false accept/reject decisions

---

## Notes

- Keep calibration artifacts controlled; trend drift vs. ambient temperature.
- Ensure test recipes and tire genealogy remain synchronized with production.
