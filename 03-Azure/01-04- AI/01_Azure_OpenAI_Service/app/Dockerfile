FROM python:3.9-slim
RUN apt-get update
RUN apt-get install -y build-essential
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 80
ENTRYPOINT ["streamlit", "run", "--server.port=80", "main.py"]