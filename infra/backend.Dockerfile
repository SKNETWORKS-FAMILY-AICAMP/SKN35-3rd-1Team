# Backend API image (Railway). Build context is the repository root because
# pyproject.toml and uv.lock live there:
#   docker build -f infra/backend.Dockerfile -t artlog-api .
FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:0.12.6 /uv /usr/local/bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dependencies first so code changes reuse this layer.
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

COPY backend ./backend
# The classifier reads the verified alias registry at runtime.
COPY data/processed ./data/processed

# Imports resolve from backend/ (app, scripts), same as local `uv run`.
WORKDIR /app/backend

# Railway injects PORT. Migrations are not run here; apply them by hand.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers --forwarded-allow-ips='*'"]
