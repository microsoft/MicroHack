import { useState } from 'react'
import type { WorkflowResponse, AgentStepResult, ToolCallInfo } from '../types/workflow'
import { normalizeAgentName } from '../types/workflow'

export type AgentStatus = 'pending' | 'running' | 'done' | 'idle' | 'error'

export interface AgentNode {
  id: string
  name: string
  description: string
}

function statusLabel(status: AgentStatus) {
  switch (status) {
    case 'running':
      return 'Working'
    case 'done':
      return 'Done'
    case 'pending':
      return 'Queued'
    case 'error':
      return 'Error'
    default:
      return 'Idle'
  }
}

/** Extracts a short summary from text output, respecting word boundaries */
function getSummary(text: string, maxLength = 150): string {
  if (!text) return ''
  const trimmed = text.trim()
  if (trimmed.length <= maxLength) return trimmed
  
  // Find the last space before maxLength to avoid cutting words
  const lastSpace = trimmed.lastIndexOf(' ', maxLength)
  const cutPoint = lastSpace > maxLength * 0.5 ? lastSpace : maxLength
  return trimmed.substring(0, cutPoint) + '…'
}

/** Checks if the step has any meaningful content to display */
function hasContent(step: AgentStepResult): boolean {
  return step.toolCalls.length > 0 || !!step.textOutput?.trim()
}

/** Checks if text output indicates an error */
function isErrorOutput(text: string): boolean {
  const lowerText = text.toLowerCase()
  // Check for various error patterns
  return (
    lowerText.includes('error') ||
    lowerText.includes('failed') ||
    lowerText.includes('exception') ||
    lowerText.includes('unable to') ||
    lowerText.includes('could not')
  )
}

/** Tool call display component */
function ToolCallDisplay({ toolCall }: { toolCall: ToolCallInfo }) {
  const [expanded, setExpanded] = useState(false)
  
  return (
    <div className="tool-call">
      <button 
        className="tool-call__header" 
        onClick={() => setExpanded(!expanded)}
        aria-expanded={expanded}
      >
        <span className="tool-call__icon">🔧</span>
        <span className="tool-call__name">{toolCall.toolName}</span>
        <span className="tool-call__toggle">{expanded ? '▼' : '▶'}</span>
      </button>
      {expanded && (
        <div className="tool-call__details">
          {toolCall.arguments && (
            <div className="tool-call__section">
              <span className="tool-call__label">Arguments:</span>
              <pre className="tool-call__code">{toolCall.arguments}</pre>
            </div>
          )}
          {toolCall.result && (
            <div className="tool-call__section">
              <span className="tool-call__label">Result:</span>
              <pre className="tool-call__code">{toolCall.result}</pre>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

/** Agent step events display component */
function AgentStepEvents({ steps }: { steps: AgentStepResult[] }) {
  const [expanded, setExpanded] = useState(false)
  
  // Merge all steps for this agent
  const allToolCalls: ToolCallInfo[] = []
  let combinedOutput = ''
  
  for (const step of steps) {
    allToolCalls.push(...step.toolCalls)
    if (step.textOutput?.trim()) {
      combinedOutput += step.textOutput + '\n'
    }
  }
  
  const hasEvents = allToolCalls.length > 0 || combinedOutput.trim()
  if (!hasEvents) return null
  
  // Prefer the backend's explicit execution status. Fall back to text matching
  // only for older or demo payloads that do not include isError.
  const isError = steps.some((step) =>
    step.isError === undefined ? isErrorOutput(step.textOutput) : step.isError,
  )
  const summary = getSummary(combinedOutput)
  
  return (
    <div className={`agent-events ${isError ? 'agent-events--error' : ''}`}>
      {allToolCalls.length > 0 && (
        <div className="agent-events__tools">
          <span className="agent-events__tools-label">
            Tool calls ({allToolCalls.length}):
          </span>
          {allToolCalls.map((tc, i) => (
            <ToolCallDisplay key={i} toolCall={tc} />
          ))}
        </div>
      )}
      
      {combinedOutput.trim() && (
        <div className="agent-events__output">
          <button 
            className="agent-events__output-header"
            onClick={() => setExpanded(!expanded)}
            aria-expanded={expanded}
          >
            <span className="agent-events__output-icon">{isError ? '⚠️' : '📝'}</span>
            <span className="agent-events__output-label">
              {isError ? 'Error Output' : 'Agent Output'}
            </span>
            <span className="agent-events__toggle">{expanded ? '▼' : '▶'}</span>
          </button>
          
          {!expanded && summary && (
            <p className="agent-events__summary">{summary}</p>
          )}
          
          {expanded && (
            <pre className="agent-events__full-output">{combinedOutput.trim()}</pre>
          )}
        </div>
      )}
    </div>
  )
}

export function AgentIllustration(props: {
  agents: AgentNode[]
  activeIndex: number | null
  runState: 'idle' | 'running' | 'completed'
  workflowResponse?: WorkflowResponse | null
  streamingSteps?: AgentStepResult[]
}) {
  const { agents, activeIndex, runState, workflowResponse, streamingSteps = [] } = props

  // Build a map of agent events from the workflow response OR streaming steps
  const agentEventsMap = new Map<string, AgentStepResult[]>()
  
  // Use final response steps if completed, otherwise use streaming steps
  const stepsToDisplay = runState === 'completed' && workflowResponse?.agentSteps 
    ? workflowResponse.agentSteps 
    : streamingSteps
  
  for (const step of stepsToDisplay) {
    const normalizedId = normalizeAgentName(step.agentName)
    const existingSteps = agentEventsMap.get(normalizedId)
    if (existingSteps) {
      existingSteps.push(step)
    } else {
      agentEventsMap.set(normalizedId, [step])
    }
  }

  const getStatus = (agentId: string, index: number): AgentStatus => {
    if (runState === 'idle') return 'idle'
    
    // If we have workflow response, determine status from actual data
    if (runState === 'completed' && workflowResponse) {
      const steps = agentEventsMap.get(agentId)
      if (steps && steps.some(s => hasContent(s))) {
        const hasExecutionError = steps.some((step) =>
          step.isError === undefined ? isErrorOutput(step.textOutput) : step.isError,
        )
        if (hasExecutionError) {
          return 'error'
        }
        return 'done'
      }
      // If no steps for this agent but workflow completed, it might have been skipped
      return steps && steps.length > 0 ? 'done' : 'pending'
    }
    
    if (runState === 'completed') return 'done'
    if (activeIndex == null) return 'pending'
    if (index < activeIndex) return 'done'
    if (index === activeIndex) return 'running'
    return 'pending'
  }

  const activeAgent =
    activeIndex == null ? null : agents[Math.min(activeIndex, agents.length - 1)]

  // Count agents with events
  const agentsWithEvents = agents.filter(a => {
    const steps = agentEventsMap.get(a.id)
    return steps && steps.some(s => hasContent(s))
  }).length

  return (
    <div className="agent-illustration" aria-label="Agents in the workflow">
      <div className="section-header">
        <div>
          <h2 className="section-title">Agent Workflow</h2>
          <p className="muted">
            {runState === 'running' && activeAgent
              ? `Currently working: ${activeAgent.name}`
              : runState === 'completed'
                ? `Workflow completed • ${agentsWithEvents} agents processed`
                : 'Waiting for an alarm'}
          </p>
        </div>
        <div className={`run-pill run-pill--${runState}`} aria-label={`Run state: ${runState}`}>
          <span className="run-pill__dot" aria-hidden="true" />
          <span className="run-pill__text">{runState}</span>
        </div>
      </div>

      <ol className="agent-list">
        {agents.map((agent, index) => {
          const status = getStatus(agent.id, index)
          const steps = agentEventsMap.get(agent.id)
          
          return (
            <li
              key={agent.id}
              className={`agent-node agent-node--${status}`}
              aria-current={status === 'running' ? 'step' : undefined}
            >
              <div className="agent-node__rail" aria-hidden="true">
                <div className="agent-node__dot" />
                {index !== agents.length - 1 && <div className="agent-node__line" />}
              </div>
              <div className="agent-node__card">
                <div className="agent-node__top">
                  <div className="agent-node__title">{agent.name}</div>
                  <span className={`badge badge--${status}`}>
                    {statusLabel(status)}
                  </span>
                </div>
                <div className="agent-node__desc">{agent.description}</div>
                
                {/* Show agent events during streaming or when completed */}
                {(runState === 'completed' || runState === 'running') && steps && (
                  <AgentStepEvents steps={steps} />
                )}
              </div>
            </li>
          )
        })}
      </ol>

      <div className="agent-legend" aria-label="Legend">
        <div className="legend-item">
          <span className="legend-swatch legend-swatch--pending" aria-hidden="true" />
          Queued
        </div>
        <div className="legend-item">
          <span className="legend-swatch legend-swatch--running" aria-hidden="true" />
          Working
        </div>
        <div className="legend-item">
          <span className="legend-swatch legend-swatch--done" aria-hidden="true" />
          Done
        </div>
        <div className="legend-item">
          <span className="legend-swatch legend-swatch--error" aria-hidden="true" />
          Error
        </div>
      </div>
    </div>
  )
}
