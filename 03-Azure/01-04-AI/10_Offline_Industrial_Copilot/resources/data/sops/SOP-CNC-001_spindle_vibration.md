# SOP-CNC-001 CNC spindle vibration and bearing replacement

- **Document:** SOP-CNC-001
- **Revision:** C (effective 2026-04-15)
- **Applies to:** CNC milling machines (CNC-03, CNC-07) and the lathe LATHE-05
- **Owner:** Maintenance Engineering
- **Related error code:** E-SPN-214 (spindle vibration high)

## Vibration limits

Vibration is measured at the spindle housing as RMS velocity.

| Level | Vibration (mm/s RMS) | Action |
|-------|----------------------|--------|
| Normal | below 4.5 | None |
| Warning | 4.5 to 7.0 | Create a medium-priority ticket. Inspect within 24 hours. |
| Stop | 7.1 or higher | Stop the machine. Create a **high-priority** ticket. Do not restart until the cause is fixed. |

Error code E-SPN-214 is raised by the controller when vibration stays above 7.1 mm/s for 10 seconds.

## First checks (about 20 minutes)

1. Complete SOP-SAF-001 (Lockout / Tagout). A spindle always needs a second person as safety observer.
2. Check the tool holder and the tool for damage, and check the clamping force.
3. Check that the tool is balanced. An unbalanced tool is the most common cause of a short vibration peak.
4. Read the bearing temperature. A bearing temperature above 75 °C together with high vibration points to bearing wear.

## Bearing replacement

Only a **spindle-certified technician** may replace the spindle bearing cartridge. Plan about 4 hours.

1. Complete SOP-SAF-001 and move the machine to the maintenance position.
2. Remove the spindle cover and disconnect the coolant line and the sensor cable.
3. Remove the old bearing cartridge. Keep the old cartridge for the failure analysis.
4. Clean the housing and fit the new cartridge (part number SPN-BRG-5518).
5. Tighten the cartridge bolts to **45 Nm** in a cross pattern, in two passes (25 Nm, then 45 Nm).
6. Refit the covers. Run the spindle warm-up program for 20 minutes at 50 percent speed.
7. Record the vibration after warm-up. It must be below **3.0 mm/s**. If it is not, call Maintenance Engineering.

## Records

Record the machine runtime hours, the vibration before and after, and the part number in the ticket.
