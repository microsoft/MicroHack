import TaskManager from './components/TaskManager'

export const dynamic = 'force-dynamic'

async function getTasks() {
  const backendUrl = process.env.BACKEND_URL || 'http://localhost:3001'
  console.log('BACKEND_URL env:', process.env.BACKEND_URL)
  console.log('Using backend URL for tasks:', backendUrl)
  try {
    const res = await fetch(`${backendUrl}/api/tasks`, {
      cache: 'no-store'
    })
    if (!res.ok) return {tasks: [], hostname: 'unknown' }
    return res.json()
  } catch (error) {
    console.error('Error fetching tasks:', error)
    return {tasks: [], hostname: 'unknown' }
  }
}

async function getHealth() {
  const backendUrl = process.env.BACKEND_URL || 'http://localhost:3001'
  console.log('Using backend URL for health:', backendUrl)
  try {
    const res = await fetch(`${backendUrl}/api/health`, {
      cache: 'no-store'
    })
    if (!res.ok) return { status: 'unhealthy' }
    return res.json()
  } catch (error) {
    console.error('Health check failed:', error)
    return { status: 'unhealthy' }
  }
}

export default async function Home() {
  const [initialTasks, healthData] = await Promise.all([
    getTasks(),
    getHealth()
  ])

  return (
    <div className="App">
      <header className="App-header">
        <h1>🚀 AKS Lab - Task Manager</h1>
        <div className="health-status">
          Backend Status: <span className={`status ${healthData.status}`}>{healthData.status}</span>
        </div>
        <div>
          Backend Status: {initialTasks.hostname}
        </div>
      </header>
      <TaskManager initialTasks={initialTasks.tasks} hostname={initialTasks.hostname} />
    </div>
  )
}
