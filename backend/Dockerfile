# Magana backend. OCR_ENGINE=tesseract (default, small) or paddle (PP-StructureV3; about
# 3 GB bigger, its models are downloaded into the image at build time, not on the first
# request). docker-compose.prod.yml passes OCR_ENGINE from the server's .env.
FROM python:3.12-slim

ARG OCR_ENGINE=tesseract
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 MAGANA_OCR=${OCR_ENGINE}

# Tesseract is always installed: it is the default engine and Paddle mode's fallback.
RUN apt-get update \
 && apt-get install -y --no-install-recommends tesseract-ocr curl \
 && if [ "$OCR_ENGINE" = "paddle" ]; then \
      apt-get install -y --no-install-recommends libgl1 libglib2.0-0 libgomp1; fi \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 magana
WORKDIR /srv
COPY requirements.txt requirements-paddle.txt ./
RUN pip install --no-cache-dir -r requirements.txt \
 && if [ "$OCR_ENGINE" = "paddle" ]; then pip install --no-cache-dir -r requirements-paddle.txt; fi

COPY app ./app
USER magana
RUN if [ "$OCR_ENGINE" = "paddle" ]; then \
      python -c "from app.reader import PaddleStructureEngine as P; P().pipeline"; fi

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
  CMD curl -fsS http://localhost:8000/health || exit 1
# One worker: PP-StructureV3 holds its models in memory per process.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--proxy-headers", "--forwarded-allow-ips", "*"]
