# Use python:3.9-slim as the base image
FROM python:3.9-slim

# Install Poetry
RUN apt-get update && apt-get install -y curl && \
    curl -sSL https://install.python-poetry.org | python3 -

# Copy pyproject.toml and poetry.lock to the container
COPY pyproject.toml poetry.lock /app/

# Set the working directory to /app
WORKDIR /app

# Run poetry install to install dependencies
RUN poetry install
