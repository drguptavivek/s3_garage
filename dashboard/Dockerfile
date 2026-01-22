FROM python:3.12-slim-bookworm

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set working directory
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv sync --frozen --no-install-project

# Copy application code
COPY . .

# Expose port
EXPOSE 8501

# Run the application
# We use `uv run` to execute in the environment created by `uv sync`
CMD ["uv", "run", "streamlit", "run", "main.py", "--server.address=0.0.0.0"]
