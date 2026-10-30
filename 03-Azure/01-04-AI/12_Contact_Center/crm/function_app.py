"""Azure Functions entry point: serves the WSGI CRM in app.py on Flex Consumption."""
import azure.functions as func

from app import app as crm

app = func.WsgiFunctionApp(app=crm, http_auth_level=func.AuthLevel.ANONYMOUS)
