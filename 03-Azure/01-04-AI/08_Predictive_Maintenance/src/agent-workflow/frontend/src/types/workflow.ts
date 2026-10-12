/**
 * Types for the workflow API response
 */

export interface ToolCallInfo {
  toolName: string
  arguments: string | null
  result: string | null
}

export interface AgentStepResult {
  agentName: string
  toolCalls: ToolCallInfo[]
  textOutput: string
  /** Explicit execution failure from the backend; absent on older/demo payloads. */
  isError?: boolean
  finalMessage: string | null
}

export interface WorkflowResponse {
  agentSteps: AgentStepResult[]
  finalMessage: string | null
}

/**
 * Maps agent IDs from the API response to display-friendly agent identifiers
 */
export function normalizeAgentName(rawName: string): string {
  const lowerName = rawName.toLowerCase()
  
  if (lowerName.includes('anomalyclassification')) return 'anomaly'
  if (lowerName.includes('faultdiagnosis')) return 'diagnosis'
  if (lowerName.includes('repairplanner')) return 'planner'
  if (lowerName.includes('maintenancescheduler')) return 'scheduler'
  if (lowerName.includes('partsordering')) return 'parts'
  if (lowerName.includes('outputmessages')) return 'output'
  
  return rawName
}

/**
 * Groups agent steps by normalized agent name
 */
export function groupStepsByAgent(steps: AgentStepResult[]): Map<string, AgentStepResult[]> {
  const grouped = new Map<string, AgentStepResult[]>()
  
  for (const step of steps) {
    const normalizedName = normalizeAgentName(step.agentName)
    if (!grouped.has(normalizedName)) {
      grouped.set(normalizedName, [])
    }
    grouped.get(normalizedName)!.push(step)
  }
  
  return grouped
}
