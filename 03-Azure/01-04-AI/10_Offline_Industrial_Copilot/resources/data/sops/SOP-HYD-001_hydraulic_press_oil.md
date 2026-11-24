# SOP-HYD-001 Hydraulic press oil temperature

- **Document:** SOP-HYD-001
- **Revision:** A (effective 2026-01-10)
- **Applies to:** hydraulic presses (PRESS-02)
- **Owner:** Maintenance Engineering
- **Related error code:** E-HYD-031 (oil temperature high)

## Limits

| Level | Oil temperature | Action |
|-------|-----------------|--------|
| Normal | below 65 °C | None |
| Warning | 65 to 75 °C | Create a medium-priority ticket. Find the cause within one shift. |
| Shutdown | above 75 °C | The controller stops the press. Do not restart until the oil is below 55 °C. |

Error code E-HYD-031 is raised at 65 °C.

## Causes and checks

1. Complete SOP-SAF-001. Release the hydraulic pressure through the bleed valve. A hydraulic circuit also needs a safety observer.
2. Check the oil cooler. Clean the cooler fins and check that the cooler fan turns.
3. Check the oil level in the sight glass. Top up with oil **ISO VG 46** only.
4. Read the return filter differential pressure. If it is above **2.5 bar**, replace the filter.
5. Check that the press cycle rate is not above the rated 18 strokes per minute.

## Oil change

Change the hydraulic oil every **4000 operating hours** or once per year, whichever comes first. A new fill is 120 litres of ISO VG 46.
