FROM python:3.11-slim

WORKDIR /server

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Install curl for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# Install dependencies first (cache layer)
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# Copy application code
COPY . .

RUN chmod +x /server/entrypoint.sh

EXPOSE 8000

CMD ["/server/entrypoint.sh"]
