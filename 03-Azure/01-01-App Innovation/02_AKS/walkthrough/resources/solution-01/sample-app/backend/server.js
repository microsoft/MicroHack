const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const { hostname } = require('os');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Storage configuration
const DATA_PATH = process.env.DATA_PATH || '/data';
const TASKS_FILE = path.join(DATA_PATH, 'tasks.json');
let usePersistentStorage = false;

// Check if persistent storage is available
try {
  if (fs.existsSync(DATA_PATH)) {
    fs.accessSync(DATA_PATH, fs.constants.W_OK);
    usePersistentStorage = true;
    console.log(`✅ Persistent storage available at: ${DATA_PATH}`);
    console.log(`📁 Tasks will be saved to: ${TASKS_FILE}`);
  }
} catch (error) {
  console.log(`⚠️  Persistent storage not available - running in EPHEMERAL mode`);
  console.log(`💡 Data will be lost when the pod restarts`);
}

// Storage functions
function loadTasks() {
  if (!usePersistentStorage) {
    return [];
  }
  
  try {
    if (fs.existsSync(TASKS_FILE)) {
      const data = fs.readFileSync(TASKS_FILE, 'utf8');
      const parsed = JSON.parse(data);
      console.log(`📖 Loaded ${parsed.tasks.length} tasks from persistent storage`);
      return parsed.tasks;
    }
  } catch (error) {
    console.error('Error loading tasks from file:', error.message);
  }
  
  return [];
}

function saveTasks(tasks) {
  if (!usePersistentStorage) {
    return;
  }
  
  try {
    const data = {
      tasks: tasks,
      lastUpdated: new Date().toISOString()
    };
    fs.writeFileSync(TASKS_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch (error) {
    console.error('Error saving tasks to file:', error.message);
  }
}

function getNextId(tasks) {
  if (tasks.length === 0) return 1;
  return Math.max(...tasks.map(t => t.id)) + 1;
}

// Initialize tasks from persistent storage or empty array
let tasks = loadTasks();
let nextId = getNextId(tasks);

// Utility function to add delay (for demonstrating scaling)
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Add request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/api/health', async (req, res) => {
  // Simulate some processing time
  await delay(100);
  
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    hostname: process.env.HOSTNAME || 'local',
    memoryUsage: process.memoryUsage()
  };
  
  res.json(health);
});

// Get all tasks
app.get('/api/tasks', async (req, res) => {
  try {
    // Simulate database query delay
    await delay(50);
    
    // Add some load simulation for scaling demo
    const load = Math.random() * 200;
    await delay(load);
    
    console.log(`Returning ${tasks.length} tasks`);
    res.json({
      tasks: tasks,
      hostname: process.env.HOSTNAME || 'local'
    });
  } catch (error) {
    console.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Get task by ID
app.get('/api/tasks/:id', async (req, res) => {
  try {
    const taskId = parseInt(req.params.id);
    const task = tasks.find(t => t.id === taskId);
    
    if (!task) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    res.json(task);
  } catch (error) {
    console.error('Error fetching task:', error);
    res.status(500).json({ error: 'Failed to fetch task' });
  }
});

// Create new task
app.post('/api/tasks', async (req, res) => {
  try {
    const { text, completed = false } = req.body;
    
    if (!text || text.trim() === '') {
      return res.status(400).json({ error: 'Task text is required' });
    }
    
    const newTask = {
      id: nextId++,
      text: text.trim(),
      completed: Boolean(completed),
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    tasks.push(newTask);
    saveTasks(tasks);
    console.log(`Created new task: ${newTask.text}`);
    
    res.status(201).json(newTask);
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// Update task
app.put('/api/tasks/:id', async (req, res) => {
  try {
    const taskId = parseInt(req.params.id);
    const { text, completed } = req.body;
    
    const taskIndex = tasks.findIndex(t => t.id === taskId);
    
    if (taskIndex === -1) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    if (text !== undefined) {
      tasks[taskIndex].text = text.trim();
    }
    
    if (completed !== undefined) {
      tasks[taskIndex].completed = Boolean(completed);
    }
    
    tasks[taskIndex].updatedAt = new Date();
    saveTasks(tasks);
    
    console.log(`Updated task ${taskId}: ${tasks[taskIndex].text}`);
    res.json(tasks[taskIndex]);
  } catch (error) {
    console.error('Error updating task:', error);
    res.status(500).json({ error: 'Failed to update task' });
  }
});

// Delete task
app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const taskId = parseInt(req.params.id);
    const taskIndex = tasks.findIndex(t => t.id === taskId);
    
    if (taskIndex === -1) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    const deletedTask = tasks.splice(taskIndex, 1)[0];
    saveTasks(tasks);
    console.log(`Deleted task ${taskId}: ${deletedTask.text}`);
    
    res.json({ message: 'Task deleted successfully', task: deletedTask });
  } catch (error) {
    console.error('Error deleting task:', error);
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

// Get application metrics (for monitoring demo)
app.get('/api/metrics', (req, res) => {
  const metrics = {
    totalTasks: tasks.length,
    completedTasks: tasks.filter(t => t.completed).length,
    pendingTasks: tasks.filter(t => !t.completed).length,
    uptime: process.uptime(),
    memoryUsage: process.memoryUsage(),
    cpuUsage: process.cpuUsage(),
    timestamp: new Date().toISOString()
  };
  
  res.json(metrics);
});

// Simulate heavy load endpoint (for load testing)
app.get('/api/load-test', async (req, res) => {
  const iterations = parseInt(req.query.iterations) || 1000;
  const start = Date.now();
  
  // Simulate CPU-intensive work
  let result = 0;
  for (let i = 0; i < iterations * 1000; i++) {
    result += Math.sqrt(i);
  }
  
  const duration = Date.now() - start;
  
  res.json({
    message: 'Load test completed',
    iterations: iterations * 1000,
    duration: `${duration}ms`,
    result: Math.round(result),
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Route not found',
    path: req.path,
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received. Shutting down gracefully...');
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Backend server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Storage mode: ${usePersistentStorage ? 'PERSISTENT' : 'EPHEMERAL'}`);
  console.log(`Health check available at: http://localhost:${PORT}/api/health`);
});