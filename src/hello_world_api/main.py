"""FastAPI application + Lambda entrypoint.

Lambda handler: ``hello_world_api.main.handler``
"""

from fastapi import FastAPI, Query
from mangum import Mangum
from pydantic import BaseModel

app = FastAPI(title="hello-world-api")


class UserForm(BaseModel):
    name: str


@app.get("/")
def hello(name: str | None = Query(default=None)):
    if name:
        return {"message": f"hello, {name}"}
    return {"message": "hello"}


@app.post("/")
def hello_user(payload: UserForm):
    return {"message": f"hello, {payload.name}"}


# AWS Lambda entrypoint. Mangum translates API Gateway / Function URL events
# into ASGI requests so FastAPI routing and validation work unchanged.
handler = Mangum(app, lifespan="off")
