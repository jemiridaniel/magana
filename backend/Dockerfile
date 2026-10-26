# Magana backend. OCR_ENGINE=tesseract (default, small) or paddle (PP-StructureV3; about
# 3 GB bigger, its models are downloaded into the image at build time, not on the first
# request). docker-compose.prod.yml passes OCR_ENGINE from the server's .env.
# SPEECH=on adds server speech (requirements-asr.txt: Whisper ASR and the MMS voices for
# WhatsApp; about 2 GB bigger, and an instance with 8 GiB: docs/DEPLOY_AWS.md §9a).
FROM python:3.12-slim

ARG OCR_ENGINE=tesseract
ARG SPEECH=off
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 MAGANA_OCR=${OCR_ENGINE}

# Tesseract is always installed: it is the default engine and Paddle mode's fallback.
RUN apt-get update \
 && apt-get install -y --no-install-recommends tesseract-ocr curl \
 && if [ "$OCR_ENGINE" = "paddle" ]; then \
      apt-get install -y --no-install-recommends libgl1 libglib2.0-0 libgomp1; fi \
 && rm -rf /var/lib/apt/lists/*

# Yorùbá and Latin-script models (tessdata_fast, Apache-2.0, pinned): a Yorùbá or Igbo page is
# read again with the one that keeps more of its letters (app/letters.py; docs/FINDINGS.md).
ARG TESSDATA_FAST=87416418657359cb625c412a48b6e1d6d41c29bd
RUN TD=$(dirname "$(find /usr/share/tesseract-ocr -name eng.traineddata | head -1)") \
 && curl -fsSL -o "$TD/yor.traineddata" "https://github.com/tesseract-ocr/tessdata_fast/raw/$TESSDATA_FAST/yor.traineddata" \
 && curl -fsSL -o "$TD/Latin.traineddata" "https://github.com/tesseract-ocr/tessdata_fast/raw/$TESSDATA_FAST/script/Latin.traineddata" \
 && echo "17ab3855f1ba9056183759a84e4c11cebf417a7d3c8c2cdcc37537d7fbffba3d  $TD/yor.traineddata" | sha256sum -c - \
 && echo "6dbdaf8ecc6c40f025c2648bf3b3f3fbffe073e1fd2df2047fde2e2b2f020d53  $TD/Latin.traineddata" | sha256sum -c -

RUN useradd --create-home --uid 10001 magana
WORKDIR /srv
COPY requirements.txt requirements-paddle.txt requirements-asr.txt ./
RUN pip install --no-cache-dir -r requirements.txt \
 && if [ "$OCR_ENGINE" = "paddle" ]; then pip install --no-cache-dir -r requirements-paddle.txt; fi \
 && if [ "$SPEECH" = "on" ]; then pip install --no-cache-dir -r requirements-asr.txt; fi

COPY app ./app
# Teachers' quizzes (MAGANA_DATA_DIR): a volume, owned by the app user.
RUN mkdir -p /data /home/magana/.cache/huggingface && chown magana /data /home/magana/.cache /home/magana/.cache/huggingface
USER magana
RUN if [ "$OCR_ENGINE" = "paddle" ]; then \
      python -c "from app.reader import PaddleStructureEngine as P; P().pipeline"; fi

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
  CMD curl -fsS http://localhost:8000/health || exit 1
# One worker: PP-StructureV3 holds its models in memory per process.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--proxy-headers", "--forwarded-allow-ips", "*"]
