FROM python:3.13-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY governance.py .
COPY main.py .

EXPOSE 8088

CMD ["python", "main.py"]
