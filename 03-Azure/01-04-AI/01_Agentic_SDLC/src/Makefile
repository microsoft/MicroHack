# OctoCAT Supply Chain Management - Makefile
# Cross-platform compatible (Linux, macOS, Windows with Git Bash or WSL)

# Detect OS for platform-specific commands
ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
    RM_RF = powershell -Command "Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
    MKDIR_P = powershell -Command "New-Item -ItemType Directory -Force -Path"
    PYTHON_CMD = python
    PYTHON_API_EXEC = $(PYTHON_CMD)
else
    DETECTED_OS := $(shell uname -s)
    RM_RF = rm -rf
    MKDIR_P = mkdir -p
    PYTHON_CMD ?= python3
    PYTHON_API_EXEC = ./.venv/bin/python
endif

API_TS_DIR := api-ts
API_CS_DIR := api-cs
API_CS_TEST_DIR := api-cs-tests
API_PY_DIR := api-py
API_JAVA_DIR := api-java
FRONTEND_DIR := frontend
PLAYWRIGHT_BROWSERS_PATH ?= $(HOME)/.cache/ms-playwright

# Resolve backend URL for frontend dev server.
# In Codespaces, browsers cannot reach container-local localhost, so use the
# forwarded host pattern: https://<codespace>-<port>.<domain>.
CODESPACES_DOMAIN := $(if $(GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN),$(GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN),app.github.dev)
define resolve_api_url
$(if $(strip $(CODESPACE_NAME)),https://$(CODESPACE_NAME)-$(1).$(CODESPACES_DOMAIN),http://localhost:$(1))
endef

TS_API_URL := $(call resolve_api_url,3000)
CS_API_URL := $(call resolve_api_url,3000)
PY_API_URL := $(call resolve_api_url,3000)
JAVA_API_URL := $(call resolve_api_url,3000)

# Default API target (TypeScript)
API_DIR := $(API_TS_DIR)

.DEFAULT_GOAL := help

##@ General

.PHONY: help
help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: info
info: ## Show detected OS and directories
	@echo "Detected OS:        $(DETECTED_OS)"
	@echo "Frontend Directory: $(FRONTEND_DIR)"
	@echo "API variants:       $(API_TS_DIR)  $(API_CS_DIR)  $(API_PY_DIR)  $(API_JAVA_DIR)"

##@ Installation

.PHONY: install
install: install-ts install-frontend ## Install all dependencies (all variants)

.PHONY: install-ts
install-ts: ## Install TypeScript API dependencies
	cd $(API_TS_DIR) && npm install

.PHONY: install-cs
install-cs: ## Restore C# API NuGet packages
	cd $(API_CS_DIR) && dotnet restore
	cd $(API_CS_TEST_DIR) && dotnet restore

.PHONY: install-py
install-py: ## Install Python API dependencies
ifeq ($(OS),Windows_NT)
	cd $(API_PY_DIR) && $(PYTHON_CMD) -m pip install -r requirements.txt
else
	cd $(API_PY_DIR) && $(PYTHON_CMD) -m venv .venv && $(PYTHON_API_EXEC) -m pip install -r requirements.txt
endif

.PHONY: install-java
install-java: ## Download Java API Maven dependencies
	cd $(API_JAVA_DIR) && mvn dependency:resolve -q

.PHONY: install-frontend
install-frontend: ## Install frontend dependencies
	cd $(FRONTEND_DIR) && npm install

##@ Development — Full Stack (API + Frontend)

.PHONY: dev
dev: dev-ts ## Start TypeScript API + frontend (default)

.PHONY: dev-ts
dev-ts: ## Start TypeScript API (port 3000) + frontend
ifeq ($(OS),Windows_NT)
	npx concurrently --kill-others "cd $(API_TS_DIR) && npm run dev" "cd $(FRONTEND_DIR) && set VITE_API_URL=$(TS_API_URL) && npm run dev"
else
	@trap 'kill 0' INT; \
	(cd $(API_TS_DIR) && npm run dev) & \
	(cd $(FRONTEND_DIR) && VITE_API_URL=$(TS_API_URL) npm run dev) & \
	wait
endif

.PHONY: dev-cs
dev-cs: ## Start C# API (port 3000) + frontend
ifeq ($(OS),Windows_NT)
	npx concurrently --kill-others "cd $(API_CS_DIR) && set PORT=3000 && dotnet run" "cd $(FRONTEND_DIR) && set VITE_API_URL=$(CS_API_URL) && npm run dev"
else
	@trap 'kill 0' INT; \
	(cd $(API_CS_DIR) && PORT=3000 dotnet run) & \
	(cd $(FRONTEND_DIR) && VITE_API_URL=$(CS_API_URL) npm run dev) & \
	wait
endif

.PHONY: dev-py
dev-py: ## Start Python API (port 3000) + frontend
ifeq ($(OS),Windows_NT)
	npx concurrently --kill-others "cd $(API_PY_DIR) && $(PYTHON_API_EXEC) -m uvicorn main:app --reload --port 3000" "cd $(FRONTEND_DIR) && set VITE_API_URL=$(PY_API_URL) && npm run dev"
else
	@trap 'kill 0' INT; \
	(cd $(API_PY_DIR) && $(PYTHON_API_EXEC) -m uvicorn main:app --reload --port 3000 --host 0.0.0.0) & \
	(cd $(FRONTEND_DIR) && VITE_API_URL=$(PY_API_URL) npm run dev) & \
	wait
endif

.PHONY: dev-java
dev-java: ## Start Java API (port 3000) + frontend
ifeq ($(OS),Windows_NT)
	npx concurrently --kill-others "cd $(API_JAVA_DIR) && mvn spring-boot:run" "cd $(FRONTEND_DIR) && set VITE_API_URL=$(JAVA_API_URL) && npm run dev"
else
	@trap 'kill 0' INT; \
	(cd $(API_JAVA_DIR) && mvn spring-boot:run) & \
	(cd $(FRONTEND_DIR) && VITE_API_URL=$(JAVA_API_URL) npm run dev) & \
	wait
endif

##@ Development — API Only

.PHONY: dev-api-ts
dev-api-ts: ## Start only the TypeScript API (port 3000)
	cd $(API_TS_DIR) && npm run dev

.PHONY: dev-api-cs
dev-api-cs: ## Start only the C# API (port 3000)
	cd $(API_CS_DIR) && PORT=3000 dotnet run

.PHONY: dev-api-py
dev-api-py: ## Start only the Python API (port 3000)
	cd $(API_PY_DIR) && $(PYTHON_API_EXEC) -m uvicorn main:app --reload --port 3000 --host 0.0.0.0

.PHONY: dev-api-java
dev-api-java: ## Start only the Java API (port 3000)
	cd $(API_JAVA_DIR) && mvn spring-boot:run

.PHONY: dev-frontend
dev-frontend: ## Start only the frontend (points to TypeScript API by default)
	cd $(FRONTEND_DIR) && npm run dev

##@ Database

.PHONY: db-init
db-init: ## Initialize database schema (TypeScript runner)
	cd $(API_TS_DIR) && npm run db:init:dev

.PHONY: db-seed
db-seed: ## Initialize and seed database with sample data (TypeScript runner)
	cd $(API_TS_DIR) && npm run db:seed:dev

##@ Building

.PHONY: build
build: build-ts build-frontend ## Build TypeScript API + frontend

.PHONY: build-ts
build-ts: ## Build the TypeScript API
	cd $(API_TS_DIR) && npm run build

.PHONY: build-cs
build-cs: ## Build the C# API
	cd $(API_CS_DIR) && dotnet build -c Release

.PHONY: build-py
build-py: ## Validate Python API (no compile step; checks imports)
	cd $(API_PY_DIR) && $(PYTHON_API_EXEC) -m py_compile main.py

.PHONY: build-java
build-java: ## Build the Java API (Maven)
	cd $(API_JAVA_DIR) && mvn package -DskipTests -q

.PHONY: build-frontend
build-frontend: ## Build the frontend
	cd $(FRONTEND_DIR) && npm run build

##@ Testing

.PHONY: test
test: test-ts test-frontend ## Run TypeScript API tests + frontend tests

.PHONY: test-ts
test-ts: ## Run TypeScript API tests
	cd $(API_TS_DIR) && npm run test

.PHONY: test-cs
test-cs: ## Run C# API tests
	cd $(API_CS_TEST_DIR) && dotnet test

.PHONY: test-py
test-py: ## Run Python API tests
	cd $(API_PY_DIR) && $(PYTHON_API_EXEC) -m pytest

.PHONY: test-java
test-java: ## Run Java API tests
	cd $(API_JAVA_DIR) && mvn test

.PHONY: install-playwright-browsers
install-playwright-browsers: ## Install Playwright browser binaries used by frontend e2e tests
	@# Skip install if a Chromium binary already exists in the cache
	@if find "$(PLAYWRIGHT_BROWSERS_PATH)" -path '*/chrome-linux/chrome' -print -quit 2>/dev/null | grep -q .; then \
		echo "Playwright Chromium already installed, skipping."; \
	else \
		$(MKDIR_P) "$(PLAYWRIGHT_BROWSERS_PATH)"; \
		cd $(FRONTEND_DIR) && PLAYWRIGHT_BROWSERS_PATH="$(PLAYWRIGHT_BROWSERS_PATH)" npx playwright install chromium; \
	fi

.PHONY: test-frontend
test-frontend: install-playwright-browsers ## Run frontend tests
	cd $(FRONTEND_DIR) && PLAYWRIGHT_BROWSERS_PATH="$(PLAYWRIGHT_BROWSERS_PATH)" npm run test

.PHONY: test-e2e
test-e2e: install-playwright-browsers ## Run end-to-end tests
	cd $(FRONTEND_DIR) && PLAYWRIGHT_BROWSERS_PATH="$(PLAYWRIGHT_BROWSERS_PATH)" npm run test:e2e

.PHONY: test-coverage
test-coverage: ## Run TypeScript API tests with coverage
	cd $(API_TS_DIR) && npm run test:coverage

##@ Linting

.PHONY: lint
lint: ## Lint TypeScript API + frontend
	cd $(API_TS_DIR) && npm run lint
	cd $(FRONTEND_DIR) && npm run lint

.PHONY: lint-fix
lint-fix: ## Lint and auto-fix TypeScript issues
	cd $(API_TS_DIR) && npm run lint:fix
	cd $(FRONTEND_DIR) && npm run lint -- --fix

.PHONY: format
format: ## Format TypeScript code with prettier
	npx prettier --write "$(API_TS_DIR)/**/*.{ts,tsx}" "$(FRONTEND_DIR)/**/*.{ts,tsx}"

##@ Code Generation

.PHONY: swagger
swagger: ## Regenerate Swagger/OpenAPI spec for TypeScript API
	cd $(API_TS_DIR) && npm run swagger:generate

##@ Production

.PHONY: start
start: ## Start TypeScript API production server
	cd $(API_TS_DIR) && npm start

##@ Docker

.PHONY: docker-build
docker-build: ## Build Docker images
	docker-compose build

.PHONY: docker-up
docker-up: ## Start Docker containers
	docker-compose up

.PHONY: docker-down
docker-down: ## Stop Docker containers
	docker-compose down

##@ Cleaning

.PHONY: clean
clean: ## Clean build artifacts and node_modules for all variants
	$(RM_RF) $(API_TS_DIR)/node_modules $(API_TS_DIR)/dist $(API_TS_DIR)/data
	$(RM_RF) $(API_CS_DIR)/bin $(API_CS_DIR)/obj $(API_CS_DIR)/data
	$(RM_RF) $(API_CS_TEST_DIR)/bin $(API_CS_TEST_DIR)/obj
	$(RM_RF) $(API_PY_DIR)/__pycache__ $(API_PY_DIR)/.pytest_cache $(API_PY_DIR)/data $(API_PY_DIR)/.venv
	$(RM_RF) $(API_JAVA_DIR)/target $(API_JAVA_DIR)/data
	$(RM_RF) $(FRONTEND_DIR)/node_modules $(FRONTEND_DIR)/dist
