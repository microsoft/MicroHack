# Building and Testing the OctoCAT Supply Chain Application

This guide provides instructions for building, running, and testing the OctoCAT Supply Chain Management application, which consists of an API component and a React Frontend.

## Prerequisites

- Node.js (version 18 or higher)
- npm (latest version recommended)
- Docker/Podman (optional, for containerization)

## Installation

1. Clone the repository
2. Install dependencies:

```bash
make install
```

## Building the Application

### Using Make Commands

You can build the entire application or its individual components using the following commands:

```bash
# Build both API and Frontend components
make build

# Build only the API component
make build-api

# Build only the Frontend component
make build-frontend
```

Alternatively, if you're in the `api/` or `frontend/` directories, you can use npm commands directly:

```bash
cd api && npm run build
cd frontend && npm run build
```

### Database management

```bash
# Initialize DB (migrations + seed)
make db-init

# Run migrations only
make db-migrate

# Seed data only
make db-seed
```

Alternatively, if you're in the `api/` directory, you can use npm commands directly:

```bash
cd api
npm run db:init
npm run db:migrate
npm run db:seed
```

Environment variables:

- DB_FILE: path to SQLite database file (default: `api/data/app.db`)
- DB_ENABLE_WAL: enable WAL mode (default: true)
- DB_FOREIGN_KEYS: enforce foreign keys (default: true)
- DB_TIMEOUT: busy timeout in ms (default: 30000)

### Using VS Code Tasks

VS Code tasks have been configured to streamline the build process:

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS) to open the Command Palette
2. Type `Tasks: Run Task` and select it
3. Choose from the following tasks:
   - `Build All`: Builds both API and Frontend components
   - `Build API`: Builds only the API component
   - `Build Frontend`: Builds only the Frontend component

Alternatively, you can press `Ctrl+Shift+B` (or `Cmd+Shift+B` on macOS) to run the default build task (`Build All`).

## Running the Application

### Using Make Commands

```bash
# Start both API and Frontend in development mode with hot reloading
make dev

# Start only the API in development mode
make dev-api

# Start only the Frontend in development mode
make dev-frontend

# Start the application in production mode
make start
```

Alternatively, if you're in the `api/` or `frontend/` directories, you can use npm commands directly:

```bash
cd api && npm run dev
cd frontend && npm run dev
```

### Using VS Code Debugger

1. Open the Debug panel (`Ctrl+Shift+D` or `Cmd+Shift+D` on macOS)
2. Select `Start API & Frontend` from the dropdown menu
3. Click the green play button or press F5

This will start both the API and Frontend in development mode with the integrated terminal, allowing you to see the console output.

## Testing the Application

### Running Tests

```bash
# Run all tests
make test

# Run API tests only
make test-api

# Run frontend tests only
make test-frontend
```

Alternatively, if you're in the `api/` or `frontend/` directories, you can use npm commands directly:

```bash
cd api && npm run test
cd frontend && npm run test
```

### Linting

```bash
# Run linting checks
make lint
```

Alternatively, if you're in the `api/` or `frontend/` directory, you can use npm commands directly:

```bash
cd frontend && npm run lint
```

```bash
cd api && npm run lint
```

## Additional Information

### Port Configuration

The API runs on port 3000 by default, and the Frontend runs on port 5137. When running in a Codespace environment, ensure that the API port visibility is set to `public` to avoid CORS errors when the Frontend tries to communicate with the API.

For Docker, the sample compose maps API to 3000 and frontend to 3001.

### Docker Deployment

The project includes Dockerfiles for both API and Frontend components and a docker-compose.yml file for easy containerized deployment:

```bash
# Build and start using Docker Compose
docker-compose up --build
```
