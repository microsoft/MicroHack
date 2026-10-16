import contextlib
import datetime
import logging
import os
import random
import json
import re

import fastapi
import fastapi.responses
import fastapi.staticfiles
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from pydantic import BaseModel
from agents import run_factory_workflow, create_maintenance_scheduler_a2a_app, create_parts_ordering_a2a_app
from agent_framework.observability import configure_otel_providers
from dotenv import load_dotenv


@contextlib.asynccontextmanager
async def lifespan(app):
    configure_otel_providers()
    yield


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = fastapi.FastAPI(lifespan=lifespan)

# Add middleware to log all requests


@app.middleware("http")
async def log_requests(request: fastapi.Request, call_next):
    logger.info(f">>> Incoming request: {request.method} {request.url.path}")
    response = await call_next(request)
    logger.info(
        f"<<< Response: {request.method} {request.url.path} - Status: {response.status_code}")
    return response

FastAPIInstrumentor.instrument_app(app, exclude_spans=["send"])

# =============================================================================
# A2A Agent Endpoints
# Mount the A2A Starlette applications for the maintenance scheduler and parts ordering agents (src/agents/)
# These can be called from the dotnet workflow using A2A protocol
# =============================================================================
try:
    # Create and mount the A2A Starlette applications directly
    # These are already Starlette apps, no need to build them
    maintenance_scheduler_starlette = create_maintenance_scheduler_a2a_app()
    parts_ordering_starlette = create_parts_ordering_a2a_app()

    app.mount("/maintenance-scheduler", maintenance_scheduler_starlette)
    app.mount("/parts-ordering", parts_ordering_starlette)
    logger.info(
        "A2A agents mounted successfully at /maintenance-scheduler and /parts-ordering")
except Exception as e:
    logger.warning(f"Failed to initialize A2A agents: {e}")


if not os.path.exists("static"):
    @app.get("/", response_class=fastapi.responses.HTMLResponse)
    async def root():
        """Root endpoint."""
        return "API service is running. Navigate to <a href='/api/weatherforecast'>/api/weatherforecast</a> to see sample data or POST to <a href='/docs'>/api/analyze_machine</a>."


@app.get("/api/weatherforecast")
async def weather_forecast():
    """Weather forecast endpoint."""
    # Generate fresh data if not in cache or cache unavailable.
    summaries = [
        "Freezing",
        "Bracing",
        "Chilly",
        "Cool",
        "Mild",
        "Warm",
        "Balmy",
        "Hot",
        "Sweltering",
        "Scorching",
    ]

    forecast = []
    for index in range(1, 6):  # Range 1 to 5 (inclusive)
        temp_c = random.randint(-20, 55)
        forecast_date = datetime.datetime.now() + datetime.timedelta(days=index)
        forecast_item = {
            "date": forecast_date.isoformat(),
            "temperatureC": temp_c,
            "temperatureF": int(temp_c * 9 / 5) + 32,
            "summary": random.choice(summaries),
        }
        forecast.append(forecast_item)

    return forecast


class AnalyzeRequest(BaseModel):
    machine_id: str
    telemetry: list[dict] | dict


@app.post("/api/analyze_machine")
async def analyze_machine(request: AnalyzeRequest):
    logger.info(f"Analyzing machine {request.machine_id}")

    try:
        outputs = await run_factory_workflow(request.machine_id, request.telemetry)

        serialized_outputs = []
        for out in outputs:
            # Handle AgentRunResponse or similar
            if hasattr(out, 'text'):
                serialized_outputs.append(out.text)
            # AgentRunResponse vs AgentRunEvent
            elif hasattr(out, 'params') and hasattr(out.params, 'text'):
                serialized_outputs.append(str(out))
            else:
                serialized_outputs.append(str(out))

        return {"results": serialized_outputs}

    except Exception as e:
        logger.error(f"Workflow failed: {e}")
        return fastapi.responses.JSONResponse(content={"error": str(e)}, status_code=500)


@app.get("/health", response_class=fastapi.responses.PlainTextResponse)
async def health_check():
    """Health check endpoint."""
    return "Healthy"


# Serve static files directly from root, if the "static" directory exists
if os.path.exists("static"):
    app.mount(
        "/",
        fastapi.staticfiles.StaticFiles(directory="static", html=True),
        name="static"
    )
