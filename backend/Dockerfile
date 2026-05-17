# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────
# ScorvoAI backend — FastAPI + Ollama integration
# Deploy targets: Railway, Render, Fly.io, Cloud Run, any Docker host
# ─────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim

# Run-time behaviour
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install Python deps first so this layer is cached unless requirements change.
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy the rest of the backend source.
COPY . .

# Drop root for security.
RUN useradd --create-home --shell /bin/bash app && chown -R app:app /app
USER app

# Default port; Railway/Render override via $PORT.
EXPOSE 8000

# Lightweight healthcheck so the orchestrator knows when we're ready.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import os,urllib.request,sys; \
sys.exit(0 if urllib.request.urlopen('http://localhost:'+os.environ.get('PORT','8000')+'/health').status==200 else 1)"

# Shell form so $PORT is expanded by sh. 2 workers handles modest load;
# bump --workers / add --timeout-keep-alive for high traffic.
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 2"]
