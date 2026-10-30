FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY tests ./tests

ENV DB_HOST=db
ENV DB_PORT=5432
ENV DB_NAME=bodegas
ENV DB_USER=app_rw
ENV DB_PASSWORD=cambiar_esto
ENV API_PORT=8000
ENV CORS_ORIGINS=http://localhost:8080

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
