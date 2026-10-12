---
title: Tire Extruder
machineType: tire_extruder
domain: tire-manufacturing
summary: Troubleshooting and maintenance guidance derived from factory KB
last_reviewed: 2025-12-29
---

# Tire Extruder

This page summarizes common issues, diagnostic steps, and fixes for tire compound extrusion.

## Operating Thresholds

- Barrel temperature: normal ≤ 118°C (overheating if above 118°C)
- Throughput: target ≥ 650 kg/h (low throughput if below 650 kg/h)

## Extruder Barrel Overheating (Priority: High)

- Fault Type: extruder_barrel_overheating
- Symptoms: Temperature exceeds 118°C; material degradation; smoke from die; discolored compound
- Likely Causes: Cooling system failure; screw wear causing excessive friction; material residence time too long; temperature control malfunction; blocked cooling passages
- Diagnostics:
  - Verify cooling water flow and temperature
  - Inspect screw and barrel for wear
  - Check material feed rate consistency
  - Test temperature controller operation
  - Inspect cooling jacket for blockages
- Corrective Actions:
  - Repair cooling system; increase water flow
  - Replace worn screw or barrel
  - Increase feed rate or adjust process
  - Replace temperature controller
  - Clean cooling passages
- Estimated Repair Time: 4–12 hours
- Impact: Material quality; compound properties compromised

## Low Material Throughput (Priority: Medium)

- Fault Type: low_material_throughput
- Symptoms: Output below 650 kg/h; production bottleneck; inconsistent extrusion rate
- Likely Causes: Screw wear reducing pumping efficiency; die restriction or blockage; feed throat bridging; motor drive issues; material feed problems
- Diagnostics:
  - Measure screw wear with borescope
  - Inspect die for carbon buildup
  - Check feed throat for material bridging
  - Monitor motor current and speed
  - Verify material feed system operation
- Corrective Actions:
  - Replace worn screw elements
  - Clean or replace die
  - Install or adjust feed throat heating/cooling
  - Service variable frequency drive (VFD)
  - Repair material feeding equipment
- Estimated Repair Time: 3–8 hours
- Impact: Production capacity; downstream starvation

---

## Notes

- Trend temperature vs. motor load to spot friction-related wear.
- Include die cleaning in preventive maintenance to stabilize throughput.
