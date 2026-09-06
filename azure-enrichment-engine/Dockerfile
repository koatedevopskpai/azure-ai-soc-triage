FROM python:3.11-slim

WORKDIR /app

COPY requirements-container.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY enrich_api.py .

EXPOSE 8001

CMD ["uvicorn", "enrich_api:app", "--host", "0.0.0.0", "--port", "8001"]