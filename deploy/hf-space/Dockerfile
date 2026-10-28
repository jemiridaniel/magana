# Magana's API on a private Hugging Face Space (Docker SDK, CPU basic; docs/INFRA.md). CI copies
# this file, README.md, backend/app, backend/requirements*.txt and content/ into the Space repo
# (scripts/build-space.sh) and pushes it; the Space builds and runs it.
# Nothing important is kept on this disk (it is lost on every restart): the database is outside
# (DATABASE_URL), photos are read in memory only, and every secret is a Space secret.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 MAGANA_OCR=tesseract \
    MAGANA_CONTENT_DIR=/srv/content MAGANA_DATA_DIR=/tmp/magana PORT=7860

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

# Hugging Face runs the container as user 1000.
RUN useradd --create-home --uid 1000 magana
WORKDIR /srv
COPY requirements.txt requirements-second-ocr.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements-second-ocr.txt \
 && pip install --no-cache-dir --no-deps rapidocr_onnxruntime==1.4.4
COPY --chown=magana app ./app
COPY --chown=magana content ./content
USER magana

EXPOSE 7860
# The Worker on api.magana.ng sets X-Forwarded-For to the caller's address (cloudflare/api-proxy);
# Hugging Face's proxy adds its own after it, and uvicorn takes the first (the rate limits).
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --proxy-headers --forwarded-allow-ips '*'"]
