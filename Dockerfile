FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy \
    UV_SYSTEM_PYTHON=1 \
    CODEX_HOME=/app/.codex

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv \
    && npm install -g @openai/codex

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen

# Copy app code and project-scoped Codex skills into the image.
COPY . .

RUN mkdir -p /app/output

RUN useradd -m -u 10001 appuser \
    && chown -R appuser:appuser /app

RUN chmod +x /app/scripts/entrypoint.sh

USER appuser

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
