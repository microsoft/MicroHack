'use client'

import { useState } from 'react'

export default function TaskManager({ initialTasks }) {
  const [tasks, setTasks] = useState(initialTasks)
  const [newTask, setNewTask] = useState('')
  const [loading, setLoading] = useState(false)

  const fetchTasks = async () => {
    try {
      setLoading(true)
      const response = await fetch('/api/tasks')
      const data = await response.json()
      setTasks(data)
    } catch (error) {
      console.error('Error fetching tasks:', error)
    } finally {
      setLoading(false)
    }
  }

  const addTask = async (e) => {
    e.preventDefault()
    if (!newTask.trim()) return

    try {
      const response = await fetch('/api/tasks', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          text: newTask,
          completed: false
        }),
      })
      const data = await response.json()
      setTasks([...tasks, data])
      setNewTask('')
    } catch (error) {
      console.error('Error adding task:', error)
    }
  }

  const toggleTask = async (id) => {
    try {
      const task = tasks.find(t => t.id === id)
      const response = await fetch(`/api/tasks/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...task,
          completed: !task.completed
        }),
      })
      const data = await response.json()
      setTasks(tasks.map(t => t.id === id ? data : t))
    } catch (error) {
      console.error('Error updating task:', error)
    }
  }

  const deleteTask = async (id) => {
    try {
      await fetch(`/api/tasks/${id}`, {
        method: 'DELETE',
      })
      setTasks(tasks.filter(t => t.id !== id))
    } catch (error) {
      console.error('Error deleting task:', error)
    }
  }

  return (
    <main className="App-main">
      <form onSubmit={addTask} className="task-form">
        <input
          type="text"
          value={newTask}
          onChange={(e) => setNewTask(e.target.value)}
          placeholder="Add a new task..."
          className="task-input"
        />
        <button type="submit" className="add-button">Add Task</button>
      </form>

      {loading ? (
        <div className="loading">Loading tasks...</div>
      ) : (
        <div className="task-list">
          {tasks.length === 0 ? (
            <p className="no-tasks">No tasks yet. Add one above!</p>
          ) : (
            tasks.map(task => (
              <div key={task.id} className={`task-item ${task.completed ? 'completed' : ''}`}>
                <input
                  type="checkbox"
                  checked={task.completed}
                  onChange={() => toggleTask(task.id)}
                />
                <span className="task-text">{task.text}</span>
                <button 
                  onClick={() => deleteTask(task.id)}
                  className="delete-button"
                >
                  ❌
                </button>
              </div>
            ))
          )}
        </div>
      )}

      <div className="stats">
        <p>Total Tasks: {tasks.length}</p>
        <p>Completed: {tasks.filter(t => t.completed).length}</p>
        <p>Remaining: {tasks.filter(t => !t.completed).length}</p>
      </div>
    </main>
  )
}
