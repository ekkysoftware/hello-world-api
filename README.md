# hello-world-api

FastAPI app that also runs on AWS Lambda via [Mangum](https://mangum.fastapiexpert.com/).

## Local development

```bash
uv sync
uv run python main.py
# or
uv run uvicorn hello_world_api.main:app --reload
```

Then open http://127.0.0.1:8000/.

## AWS Lambda

`src/hello_world_api/main.py` exposes the Lambda handler:

```python
handler = Mangum(app, lifespan="off")
```

Configure the Lambda function handler as:

```
hello_world_api.main.handler
```

Build the deployment artifact with:

```bash
./scripts/build_lambda.sh   # -> dist/lambda.zip (deps + hello_world_api/)
```

The function needs the project dependencies packaged (for example with a
container image or a zip containing the package and the installed packages).
Requests are translated from API Gateway / Lambda Function URL events into
ASGI requests by Mangum, and the FastAPI response is returned in the format
API Gateway expects.

## CI/CD

See [docs/ci-cd.md](docs/ci-cd.md) for the GitHub Actions pipeline, required
repository variables/secrets, and the contract with the Pulumi infra.
