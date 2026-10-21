"""Local development entrypoint.

The Lambda handler is ``hello_world_api.main.handler``; this file only exists so
``uv run python main.py`` keeps working. Requires ``uv sync`` first.
"""

from hello_world_api.main import app

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
