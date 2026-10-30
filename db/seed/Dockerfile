FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY seed.py .
COPY catalogos ./catalogos

ENV DB_HOST=db
ENV DB_PORT=5432
ENV POSTGRES_DB=bodegas
ENV POSTGRES_USER=bodegas_owner
ENV POSTGRES_PASSWORD=cambiar_esto
ENV SEED=42

CMD ["python", "seed.py"]
