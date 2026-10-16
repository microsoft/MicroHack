import { useMemo, useState, useCallback, useRef } from 'react'
import aspireLogo from '/Aspire.png'
import './App.css'

import { AlarmForm, type AnalyzeMachinePayload } from './components/AlarmForm'
import { AgentIllustration, type AgentNode } from './components/AgentIllustration'
import type { WorkflowResponse, AgentStepResult } from './types/workflow'
import { streamAnalyzeMachine } from './api/streamAnalyze'

// Sample workflow response for demo purposes
const DEMO_WORKFLOW_RESPONSE: WorkflowResponse = {
  agentSteps: [
    {
      agentName: "AnomalyClassificationAgent_AnomalyClassificationAgent_5",
      toolCalls: [],
      textOutput: "",
      finalMessage: null
    },
    {
      agentName: "AnomalyClassificationAgent_AnomalyClassificationAgent_5",
      toolCalls: [
        {
          toolName: "getMachine",
          arguments: "{\"id\":\"machine-001\"}",
          result: null
        },
        {
          toolName: "getThreshold",
          arguments: "{\"machineType\":\"tire_curing_press\"}",
          result: null
        }
      ],
      textOutput: "{\n  \"status\": \"medium\",\n  \"alerts\": [\n    {\n      \"name\": \"curing_temperature\",\n      \"severity\": \"warning\",\n      \"description\": \"Curing temperature recorded at 179.2°C, which exceeds the warning threshold of 178°C but not the critical threshold (182°C).\"\n    },\n    {\n      \"name\": \"cycle_time\",\n      \"severity\": \"warning\",\n      \"description\": \"Cycle time measured at 14.5 minutes, which exceeds the warning threshold of 14 minutes but is below the critical threshold (16 minutes).\"\n    }\n  ],\n  \"summary\": {\n    \"totalRecordsProcessed\": 2,\n    \"violations\": { \"critical\": 0, \"warning\": 2 }\n  }\n}\n\nSummary: Both curing temperature (179.2°C) and cycle time (14.5 min) for Tire Curing Press A1 are above their respective warning thresholds but below critical limits. Immediate attention is suggested to prevent escalation into critical failure. No critical violations were observed in this telemetry sample.",
      finalMessage: null
    },
    {
      agentName: "FaultDiagnosisAgent_FaultDiagnosisAgent_2",
      toolCalls: [],
      textOutput: "",
      finalMessage: null
    },
    {
      agentName: "FaultDiagnosisAgent_FaultDiagnosisAgent_2",
      toolCalls: [
        {
          toolName: "getMachine",
          arguments: "{\"id\":\"machine-001\"}",
          result: null
        }
      ],
      textOutput: "{\n  \"MachineId\": \"machine-001\",\n  \"FaultType\": \"curing_temperature_excessive\",\n  \"RootCause\": \"Heating element malfunction\",\n  \"Severity\": \"High\",\n  \"DetectedAt\": \"2024-06-17T00:21:13Z\"\n}",
      finalMessage: null
    },
    {
      agentName: "RepairPlannerAgent_3fb5335ca1f54fdd969e4e840d74169c",
      toolCalls: [],
      textOutput: "",
      finalMessage: null
    },
    {
      agentName: "RepairPlannerAgent_3fb5335ca1f54fdd969e4e840d74169c",
      toolCalls: [
        {
          toolName: "GetAvailableTechnicians",
          arguments: "{\"requiredSkills\":[\"electrical\",\"heating systems\"],\"department\":\"Maintenance\"}",
          result: "[]"
        },
        {
          toolName: "CreateWorkOrder",
          arguments: "{\"machineId\":\"machine-001\",\"faultType\":\"curing_temperature_excessive\",\"priority\":\"high\"}",
          result: "{\"workOrderId\":\"wo-2026-26e49738\",\"status\":\"created\"}"
        }
      ],
      textOutput: "Work Order ID: WO-2026-26E49738\n\nMachine ID: machine-001\n\nFault Type: curing_temperature_excessive (Heating element malfunction)\n\nPriority: High\n\nAssigned Technician: None currently available with required skills.\n\nEstimated Duration: 120 minutes\n\nRepair Tasks:\n1. Lock out and tag out (LOTO) the machine\n2. Test heating element resistance\n3. Replace component if faulty\n4. Recalibrate temperature sensor",
      finalMessage: null
    },
    {
      agentName: "MaintenanceSchedulerAgent_b8a9a9a43b91474689180c7957021038",
      toolCalls: [],
      textOutput: "",
      finalMessage: null
    },
    {
      agentName: "MaintenanceSchedulerAgent_b8a9a9a43b91474689180c7957021038",
      toolCalls: [],
      textOutput: "Error processing maintenance schedule request: Work order not found",
      finalMessage: null
    },
    {
      agentName: "PartsOrderingAgent_83df9000225a48c999e49d058cb54c6d",
      toolCalls: [],
      textOutput: "",
      finalMessage: null
    },
    {
      agentName: "PartsOrderingAgent_83df9000225a48c999e49d058cb54c6d",
      toolCalls: [],
      textOutput: "Error processing parts order request: Work order not found",
      finalMessage: null
    }
  ],
  finalMessage: "Workflow completed with errors in maintenance scheduling and parts ordering."
}

function App() {
  const apiBaseUrl = import.meta.env.VITE_API_URL as string | undefined
  // Use streaming endpoint for real-time updates
  const analyzeStreamUrl = apiBaseUrl
    ? new URL('/api/analyze_machine/stream', apiBaseUrl).toString()
    : '/api/analyze_machine/stream'

  const agents = useMemo<AgentNode[]>(
    () => [
      {
        id: 'anomaly',
        name: 'Anomaly Classification Agent',
        description: 'Determines whether the alarm indicates an anomaly and classifies severity.',
      },
      {
        id: 'diagnosis',
        name: 'Fault Diagnosis Agent',
        description: 'Analyzes symptoms and proposes likely root causes and next checks.',
      },
      {
        id: 'planner',
        name: 'Repair Planner Agent',
        description: 'Drafts a repair plan, parts list, and recommended technician actions.',
      },
      {
        id: 'scheduler',
        name: 'Maintenance Scheduler Agent',
        description: 'Schedules maintenance windows and assigns technicians based on availability.',
      },
      {
        id: 'parts',
        name: 'Parts Ordering Agent',
        description: 'Orders required parts from inventory or external suppliers.',
      },
    ],
    [],
  )

  const [submittedPayload, setSubmittedPayload] = useState<AnalyzeMachinePayload | null>(null)
  const [runState, setRunState] = useState<'idle' | 'running' | 'completed'>('idle')
  const [activeIndex, setActiveIndex] = useState<number | null>(null)
  const [apiResponse, setApiResponse] = useState<WorkflowResponse | null>(null)
  const [apiError, setApiError] = useState<string | null>(null)
  
  // Accumulate steps as they stream in
  const [streamingSteps, setStreamingSteps] = useState<AgentStepResult[]>([])
  
  // AbortController for canceling in-flight requests
  const abortControllerRef = useRef<AbortController | null>(null)

  const callAnalyzeMachine = useCallback(async (payload: AnalyzeMachinePayload) => {
    // Cancel any in-flight request
    abortControllerRef.current?.abort()
    abortControllerRef.current = new AbortController()

    setSubmittedPayload(payload)
    setRunState('running')
    setApiResponse(null)
    setApiError(null)
    setStreamingSteps([])
    setActiveIndex(0)

    try {
      await streamAnalyzeMachine(
        analyzeStreamUrl,
        payload,
        {
          onWorkflowStarted: (evt) => {
            console.log('Workflow started:', evt.agentPipeline)
          },
          onAgentStarted: (evt) => {
            console.log('Agent started:', evt.agentName, 'index:', evt.agentIndex)
            setActiveIndex(evt.agentIndex)
          },
          onAgentCompleted: (evt) => {
            console.log('Agent completed:', evt.step.agentName)
            setStreamingSteps((prev) => [...prev, evt.step])
          },
          onWorkflowCompleted: (evt) => {
            console.log('Workflow completed')
            setApiResponse(evt.result)
            setRunState('completed')
            setActiveIndex(null)
          },
          onError: (error) => {
            console.error('Workflow error:', error)
            setApiError(error)
            setRunState('idle')
            setActiveIndex(null)
          },
        },
        abortControllerRef.current.signal
      )
    } catch (err) {
      if ((err as Error).name === 'AbortError') {
        console.log('Request aborted')
        return
      }
      setApiError(err instanceof Error ? err.message : 'Request failed')
      setRunState('idle')
      setActiveIndex(null)
    }
  }, [analyzeStreamUrl])

  const loadDemoData = () => {
    setSubmittedPayload({
      machine_id: 'machine-001',
      telemetry: [
        { metric: 'curing_temperature', value: 179.2 },
        { metric: 'cycle_time', value: 14.5 },
      ],
    })
    setApiResponse(DEMO_WORKFLOW_RESPONSE)
    setRunState('completed')
    setApiError(null)
  }

  const reset = () => {
    abortControllerRef.current?.abort()
    setRunState('idle')
    setSubmittedPayload(null)
    setApiResponse(null)
    setApiError(null)
    setStreamingSteps([])
    setActiveIndex(null)
  }

  return (
    <div className="app-container">
      <header className="app-header">
        <a 
          href="https://aspire.dev" 
          target="_blank" 
          rel="noopener noreferrer"
          aria-label="Visit Aspire website (opens in new tab)"
          className="logo-link"
        >
          <img src={aspireLogo} className="logo" alt="Aspire logo" />
        </a>
        <h1 className="app-title">Factory Agent Workflow</h1>
        <p className="app-subtitle">
          Define an alert, then watch agents process it.
        </p>
      </header>

      <main className="main-content">
        <section className="workflow-layout" aria-label="Alarm submission and agent workflow">
          <div className="card">
            <AlarmForm disabled={runState === 'running'} onSubmit={callAnalyzeMachine} />

            {apiError && (
              <div className="error-message" role="alert" aria-live="polite">
                <span>{apiError}</span>
              </div>
            )}

            <div className="card-footer">
              <button
                type="button"
                className="secondary-button"
                onClick={reset}
                disabled={runState === 'running'}
              >
                Reset
              </button>
              <button
                type="button"
                className="secondary-button"
                onClick={loadDemoData}
                disabled={runState === 'running'}
              >
                Load Demo
              </button>
              <div className="muted">
                {runState === 'running'
                  ? 'Calling API…'
                  : apiBaseUrl
                    ? `Using VITE_API_URL: ${apiBaseUrl}`
                    : 'Using relative /api (Vite proxy).'}
              </div>
            </div>
          </div>

          <div className="card">
            <AgentIllustration 
              agents={agents} 
              activeIndex={activeIndex} 
              runState={runState} 
              workflowResponse={apiResponse}
              streamingSteps={streamingSteps}
            />

            <div className="submitted-preview">
              <div className="section-header">
                <h2 className="section-title">Request/response</h2>
              </div>
              <div className="request-response-grid">
                <div>
                  <div className="muted">Request</div>
                  {submittedPayload ? (
                    <pre className="code-block" aria-label="Request JSON">
                      {JSON.stringify(submittedPayload, null, 2)}
                    </pre>
                  ) : (
                    <div className="muted">Submit to see request payload.</div>
                  )}
                </div>
                <div>
                  <div className="muted">Response</div>
                  {apiResponse != null ? (
                    <pre className="code-block" aria-label="Response">
                      {typeof apiResponse === 'string'
                        ? apiResponse
                        : JSON.stringify(apiResponse, null, 2)}
                    </pre>
                  ) : (
                    <div className="muted">Awaiting response.</div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="app-footer">
        <nav aria-label="Footer navigation">
          <a href="https://aspire.dev" target="_blank" rel="noopener noreferrer">
            Built on Aspire + Vite<span className="visually-hidden"> (opens in new tab)</span>
          </a>
          <a 
            href="https://github.com/dotnet/aspire" 
            target="_blank" 
            rel="noopener noreferrer"
            className="github-link"
            aria-label="View Aspire on GitHub (opens in new tab)"
          >
            <img src="/github.svg" alt="" width="24" height="24" aria-hidden="true" />
            <span className="visually-hidden">GitHub</span>
          </a>
        </nav>
      </footer>
    </div>
  )
}

export default App
