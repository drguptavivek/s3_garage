FROM python:3.13-slim-bookworm

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

# Add venv to PATH
ENV PATH="/app/.venv/bin:$PATH"

# Copy application code
COPY . .

# Expose port
EXPOSE 8501

# Run the application
CMD ["uv", "run", "streamlit", "run", "main.py", "--server.address=0.0.0.0"]
