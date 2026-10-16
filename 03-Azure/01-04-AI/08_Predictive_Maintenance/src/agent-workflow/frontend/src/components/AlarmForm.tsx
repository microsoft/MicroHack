import { useId, useMemo, useState } from 'react'

export interface AnalyzeMachinePayload {
  machine_id: string
  telemetry: unknown
}

export function AlarmForm(props: {
  disabled?: boolean
  onSubmit: (payload: AnalyzeMachinePayload) => void
}) {
  const machineIdInputId = useId()
  const telemetryInputId = useId()

  const [machineId, setMachineId] = useState('machine-001')
  const [telemetryText, setTelemetryText] = useState(
    JSON.stringify(
      [
        { metric: 'curing_temperature', value: 179.2 },
        { metric: 'cycle_time', value: 14.5 },
      ],
      null,
      2,
    ),
  )

  const [touched, setTouched] = useState(false)

  const validation = useMemo(() => {
    const errors: string[] = []
    if (!machineId.trim()) errors.push('Machine ID is required.')

    let parsedTelemetry: unknown = null
    try {
      parsedTelemetry = telemetryText.trim() ? JSON.parse(telemetryText) : null
    } catch {
      errors.push('Telemetry must be valid JSON.')
    }

    if (parsedTelemetry == null) errors.push('Telemetry is required.')

    return {
      ok: errors.length === 0,
      errors,
      parsedTelemetry,
    }
  }, [machineId, telemetryText])

  const submit = () => {
    setTouched(true)
    if (!validation.ok) return

    props.onSubmit({
      machine_id: machineId.trim(),
      telemetry: validation.parsedTelemetry,
    })
  }

  return (
    <form
      className="alarm-form"
      onSubmit={(e) => {
        e.preventDefault()
        submit()
      }}
    >
      <div className="section-header">
        <div>
          <h2 className="section-title">Define an anomaly</h2>
          <p className="muted">
            Posts JSON to <span className="inline-code">/api/analyze_machine</span>.
          </p>
        </div>
        <button
          className="primary-button"
          type="submit"
          disabled={props.disabled}
          aria-disabled={props.disabled}
        >
          {props.disabled ? 'Running…' : 'Trigger anomaly'}
        </button>
      </div>

      {touched && !validation.ok && (
        <div className="error-message" role="alert" aria-live="polite">
          <span>
            {validation.errors.length === 1
              ? validation.errors[0]
              : 'Please fix the highlighted fields.'}
          </span>
        </div>
      )}

      <div className="form-grid">
        <div className="field">
          <label htmlFor={machineIdInputId}>Machine ID</label>
          <input
            id={machineIdInputId}
            type="text"
            value={machineId}
            onChange={(e) => setMachineId(e.target.value)}
            placeholder="e.g., machine-001"
            disabled={props.disabled}
            required
          />
        </div>

        <div className="field span-2">
          <label htmlFor={telemetryInputId}>Telemetry (JSON)</label>
          <textarea
            id={telemetryInputId}
            value={telemetryText}
            onChange={(e) => setTelemetryText(e.target.value)}
            placeholder='[{"metric":"curing_temperature","value":179.2}]'
            rows={8}
            disabled={props.disabled}
          />
        </div>
      </div>
    </form>
  )
}
