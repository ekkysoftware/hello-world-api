from fastapi.testclient import TestClient

from hello_world_api.main import app, handler

client = TestClient(app)


def test_get_hello_default():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "hello"}


def test_get_hello_with_name():
    response = client.get("/", params={"name": "Alice"})
    assert response.status_code == 200
    assert response.json() == {"message": "hello, Alice"}


def test_post_hello():
    response = client.post("/", json={"name": "Alice"})
    assert response.status_code == 200
    assert response.json() == {"message": "hello, Alice"}


def test_post_hello_requires_name():
    response = client.post("/", json={})
    assert response.status_code == 422


def _http_api_v2_event(path="/", method="GET", query=None, body=None):
    """Minimal API Gateway HTTP API (payload v2) event, what Mangum receives."""
    return {
        "version": "2.0",
        "routeKey": f"{method} {path}",
        "rawPath": path,
        "rawQueryString": "",
        "headers": {"content-type": "application/json"},
        "queryStringParameters": query,
        "requestContext": {
            "accountId": "000000000000",
            "apiId": "test",
            "domainName": "test.execute-api.us-east-1.amazonaws.com",
            "http": {
                "method": method,
                "path": path,
                "protocol": "HTTP/1.1",
                "sourceIp": "127.0.0.1",
                "userAgent": "pytest",
            },
            "requestId": "test-request",
            "routeKey": f"{method} {path}",
            "stage": "$default",
            "time": "01/Jan/2026:00:00:00 +0000",
            "timeEpoch": 0,
        },
        "body": body,
        "isBase64Encoded": False,
    }


def test_lambda_handler_serves_get():
    response = handler(_http_api_v2_event(), None)
    assert response["statusCode"] == 200
    assert response["body"] == '{"message":"hello"}'
