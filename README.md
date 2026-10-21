# hello-world-api

FastAPI app that also runs on AWS Lambda via [Mangum](https://mangum.fastapiexpert.com/).

## Local development

```bash
uv sync
uv run python main.py
# or
uv run uvicorn main:app --reload
```

Then open http://127.0.0.1:8000/.

## AWS Lambda

`main.py` exposes the Lambda handler as `handler`:

```python
handler = Mangum(app)
```

Configure the Lambda function handler as:

```
main.handler
```

The function needs the project dependencies packaged (for example with a
container image or a zip containing `main.py` and the installed packages).
Requests are translated from API Gateway / Lambda Function URL events into
ASGI requests by Mangum, and the FastAPI response is returned in the format
API Gateway expects.
