"""Hello World API — FastAPI application packaged for AWS Lambda."""

from hello_world_api.main import app, handler

__all__ = ["app", "handler"]
