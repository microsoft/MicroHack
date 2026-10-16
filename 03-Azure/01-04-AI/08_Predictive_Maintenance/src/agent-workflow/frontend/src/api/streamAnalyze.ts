import type { WorkflowResponse, AgentStepResult } from '../types/workflow'

/**
 * SSE event types matching the backend WorkflowEvent classes
 */
export interface WorkflowStartedEvent {
  type: 'workflow_started'
  timestamp: string
  agentPipeline: string[]
}

export interface AgentStartedEvent {
  type: 'agent_started'
  timestamp: string
  agentName: string
  agentIndex: number
}

export interface AgentCompletedEvent {
  type: 'agent_completed'
  timestamp: string
  step: AgentStepResult
}

export interface WorkflowCompletedEvent {
  type: 'workflow_completed'
  timestamp: string
  result: WorkflowResponse
}

export interface WorkflowErrorEvent {
  type: 'workflow_error'
  timestamp: string
  error: string
}

export type WorkflowEvent =
  | WorkflowStartedEvent
  | AgentStartedEvent
  | AgentCompletedEvent
  | WorkflowCompletedEvent
  | WorkflowErrorEvent

/**
 * Callbacks for handling SSE events during workflow execution
 */
export interface StreamCallbacks {
  onWorkflowStarted?: (event: WorkflowStartedEvent) => void
  onAgentStarted?: (event: AgentStartedEvent) => void
  onAgentCompleted?: (event: AgentCompletedEvent) => void
  onWorkflowCompleted?: (event: WorkflowCompletedEvent) => void
  onError?: (error: string) => void
}

/**
 * Stream workflow analysis via Server-Sent Events.
 * 
 * Uses fetch + ReadableStream to handle SSE from a POST endpoint
 * (native EventSource only supports GET requests).
 */
export async function streamAnalyzeMachine(
  url: string,
  payload: { machine_id: string; telemetry: unknown },
  callbacks: StreamCallbacks,
  signal?: AbortSignal
): Promise<void> {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    signal,
  })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(text || `Request failed with ${response.status}`)
  }

  if (!response.body) {
    throw new Error('Response body is null')
  }

  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''

  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })

      // Parse SSE events from buffer (format: "data: {...}\n\n")
      const lines = buffer.split('\n\n')
      buffer = lines.pop() || '' // Keep incomplete chunk in buffer

      for (const line of lines) {
        if (!line.startsWith('data: ')) continue
        
        const json = line.slice(6) // Remove "data: " prefix
        if (!json.trim()) continue

        try {
          const event = JSON.parse(json) as WorkflowEvent
          
          switch (event.type) {
            case 'workflow_started':
              callbacks.onWorkflowStarted?.(event as WorkflowStartedEvent)
              break
            case 'agent_started':
              callbacks.onAgentStarted?.(event as AgentStartedEvent)
              break
            case 'agent_completed':
              callbacks.onAgentCompleted?.(event as AgentCompletedEvent)
              break
            case 'workflow_completed':
              callbacks.onWorkflowCompleted?.(event as WorkflowCompletedEvent)
              break
            case 'workflow_error':
              callbacks.onError?.((event as WorkflowErrorEvent).error)
              break
          }
        } catch (parseError) {
          console.warn('Failed to parse SSE event:', json, parseError)
        }
      }
    }
  } finally {
    reader.releaseLock()
  }
}
