"""Azure Functions entry point: serves the WSGI back-office app in app.py on Flex Consumption."""
import azure.functions as func

from app import app as backoffice

app = func.WsgiFunctionApp(app=backoffice, http_auth_level=func.AuthLevel.ANONYMOUS)
