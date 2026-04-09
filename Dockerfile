# ── Stage 1: Builder ────────────────────────────────────────────────────────
FROM python:3.14-slim AS builder

# Install uv for fast dependency resolution
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /build

# Copy dependency files first (better layer caching)
COPY pyproject.toml uv.lock requirements.txt README.md ./
COPY src/ ./src/

# Install dependencies into a virtual environment inside /build/.venv
ENV UV_PROJECT_ENVIRONMENT=/build/.venv \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

RUN uv sync --frozen --no-dev && rm README.md


# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM python:3.14-slim AS runtime

# Non-root user for security
RUN groupadd --gid 1001 jamf && \
    useradd --uid 1001 --gid jamf --shell /bin/bash --create-home jamf

WORKDIR /app

# Copy virtual environment and source from builder
COPY --from=builder /build/.venv /app/.venv
COPY --from=builder /build/src /app/src

# Make sure the venv binaries are on PATH
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Drop to non-root
USER jamf

# Expose port for SSE / streamable-http transport (not used in stdio mode)
EXPOSE 8000

ENTRYPOINT ["python", "-m", "jamf_mcp.server"]
