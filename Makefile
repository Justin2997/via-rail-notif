# Makefile

.PHONY: test install run lint

test: install
	@echo "Running tests..."
	poetry run pytest

run: install
	@echo "Running the application..."
	poetry run uvicorn via_rail_notif.main:app --reload

install:
	@echo "Installing dependencies..."
	poetry install

lint:
	@echo "Running linter..."
	poetry run flake8 via_rail_notif