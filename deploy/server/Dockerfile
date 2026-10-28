# Magana's API on the test-phase server (Oracle Cloud, London, arm64; docs/INFRA.md). Built on the
# server itself from the repository root by magana-deploy, for the commit CI tagged "production":
#   docker build -f deploy/server/Dockerfile --build-arg BUILD=<commit> -t magana-api:<commit> .
# Nothing important is kept in the container: the database is outside (DATABASE_URL), photos are
# read in memory only, and the settings come from /etc/magana/magana.env on the host.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 MAGANA_OCR=tesseract \
    MAGANA_CONTENT_DIR=/srv/content MAGANA_DATA_DIR=/data

RUN apt-get update \
 && apt-get install -y --no-install-recommends tesseract-ocr curl \
 && rm -rf /var/lib/apt/lists/*

# Yorùbá and Latin-script models (tessdata_fast, Apache-2.0, pinned), as backend/Dockerfile.
ARG TESSDATA_FAST=87416418657359cb625c412a48b6e1d6d41c29bd
RUN TD=$(dirname "$(find /usr/share/tesseract-ocr -name eng.traineddata | head -1)") \
 && curl -fsSL -o "$TD/yor.traineddata" "https://github.com/tesseract-ocr/tessdata_fast/raw/$TESSDATA_FAST/yor.traineddata" \
 && curl -fsSL -o "$TD/Latin.traineddata" "https://github.com/tesseract-ocr/tessdata_fast/raw/$TESSDATA_FAST/script/Latin.traineddata" \
 && echo "17ab3855f1ba9056183759a84e4c11cebf417a7d3c8c2cdcc37537d7fbffba3d  $TD/yor.traineddata" | sha256sum -c - \
 && echo "6dbdaf8ecc6c40f025c2648bf3b3f3fbffe073e1fd2df2047fde2e2b2f020d53  $TD/Latin.traineddata" | sha256sum -c -

RUN useradd --create-home --uid 10001 magana && mkdir -p /data && chown magana /data
WORKDIR /srv
COPY backend/requirements.txt backend/requirements-second-ocr.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements-second-ocr.txt \
 && pip install --no-cache-dir --no-deps rapidocr_onnxruntime==1.4.4
COPY backend/app ./app
COPY content ./content
# The commit, for /health and /livez: the deploy waits until the server answers with it.
ARG BUILD=""
RUN echo "$BUILD" > app/build.txt
USER magana

EXPOSE 8000
# /livez, not /health: no database query, so Neon's free compute can sleep (docs/INFRA.md).
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
  CMD curl -fsS http://localhost:8000/livez || exit 1
# Caddy on the host sets X-Forwarded-For to the caller's address (deploy/server/Caddyfile); the
# container's port is published on 127.0.0.1 only, so nothing else can reach it.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--proxy-headers", "--forwarded-allow-ips", "*"]
