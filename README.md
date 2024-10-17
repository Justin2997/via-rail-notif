# via-rail-notif

## Running the FastAPI Application

To run the FastAPI application, execute the following command:

```bash
uvicorn main:app --reload
```

This will start the server and you can access the "Hello World" message at `http://127.0.0.1:8000/`.

## Running the FastAPI Application with Poetry

To run the FastAPI application using Poetry, execute the following command:

```bash
poetry run uvicorn main:app --reload
```

This will start the server and you can access the "Hello World" message at `http://127.0.0.1:8000/`.

## Installing Dependencies

To install the necessary dependencies using Poetry, execute the following commands:

```bash
poetry add fastapi uvicorn
```

## Linting the Code

To lint the code using Poetry, execute the following command:

```bash
poetry run flake8
```
