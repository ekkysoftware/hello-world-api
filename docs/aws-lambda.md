FastAPI works very well on AWS Lambda when you put an adapter between Lambda’s event-based invocation model and FastAPI’s ASGI request model. The usual architecture is **API Gateway → Lambda → FastAPI**, with either **Mangum** or **AWS Lambda Web Adapter** doing the translation. [builder.aws](https://builder.aws.com/content/3KHzA4aOtupX6ZZg04EwGFUpRX4/deploy-fastapi-to-aws-lambda-in-minutes)

## How it works

Lambda does not run a persistent HTTP server such as Uvicorn by default; it receives JSON events from API Gateway. An adapter converts those events into ASGI requests, lets FastAPI route and validate them, then converts FastAPI’s response back into Lambda/API Gateway format. [builder.aws](https://builder.aws.com/content/3KHzA4aOtupX6ZZg04EwGFUpRX4/deploy-fastapi-to-aws-lambda-in-minutes)

```text
Client
  → API Gateway HTTP API
  → Lambda
  → Mangum / Lambda Web Adapter
  → FastAPI app
  → response back to client
```

## Two practical approaches

| Approach | How it works | Best for |
|---|---|---|
| **Mangum** | Wrap the FastAPI app as a Lambda handler: `handler = Mangum(app)` | Lowest cold-start overhead and a simple Python-only deployment.  [builder.aws](https://builder.aws.com/content/3KHzA4aOtupX6ZZg04EwGFUpRX4/deploy-fastapi-to-aws-lambda-in-minutes) |
| **AWS Lambda Web Adapter** | Lambda starts Uvicorn locally on port 8080; the adapter proxies Lambda events to it as normal HTTP | Keeping your FastAPI app completely unchanged and portable across Lambda, ECS, and local development.  [builder.aws](https://builder.aws.com/content/3Ee4zoARhywavup2worwNXvD5rK/deploy-fastapi-to-aws-in-60-seconds) |

With Mangum, the code change is minimal:

```python
from mangum import Mangum
from app.main import app

handler = Mangum(app, lifespan="off")
```

Then deploy with AWS SAM, CDK, Terraform, or the AWS CLI, and expose it through an API Gateway HTTP API using a catch-all route such as `ANY /{proxy+}` so FastAPI retains control of routing. [builder.aws](https://builder.aws.com/content/3KHzA4aOtupX6ZZg04EwGFUpRX4/deploy-fastapi-to-aws-lambda-in-minutes)

## Why it is a good fit

- **Scale to zero:** You pay only for invocations and compute time, rather than keeping a server running during idle periods. [builder.aws](https://builder.aws.com/content/3KHzA4aOtupX6ZZg04EwGFUpRX4/deploy-fastapi-to-aws-lambda-in-minutes)
- **Automatic scaling:** Lambda can handle bursts without you configuring scaling groups. [cloudwebschool](https://cloudwebschool.com/docs/aws/compute/fastapi-on-lambda/)
- **FastAPI features survive:** Routing, Pydantic validation, dependency injection, async handlers, and Swagger docs at `/docs` still work. [builder.aws](https://builder.aws.com/content/3Ee4zoARhywavup2worwNXvD5rK/deploy-fastapi-to-aws-in-60-seconds)
- **Low operational burden:** No EC2 patching or always-on container management for low-to-moderate traffic. [cloudwebschool](https://cloudwebschool.com/docs/aws/compute/fastapi-on-lambda/)

## Important limitations

- **Statelessness:** Do not store application data in module-level dictionaries; Lambda environments can be recycled and concurrent executions do not share memory. Use DynamoDB, S3, or RDS with RDS Proxy. [cloudwebschool](https://cloudwebschool.com/docs/aws/compute/fastapi-on-lambda/)
- **Cold starts:** A minimal FastAPI app commonly takes roughly 0.5–1 second to cold-start; heavy libraries such as pandas, NumPy, or ML models can make this much worse. [cloudwebschool](https://cloudwebschool.com/docs/aws/compute/fastapi-on-lambda/)
- **Execution limits:** Lambda has a 15-minute maximum invocation duration, so it is unsuitable for long-running jobs. [cloudwebschool](https://cloudwebschool.com/docs/aws/compute/fastapi-on-lambda/)
- **Database connections:** Many concurrent Lambda executions can exhaust a relational database’s connection pool; use RDS Proxy for RDS/PostgreSQL/MySQL workloads. [cloudwebschool](https://cloudwebschool.com/docs/aws/compute/fastapi-on-lambda/)
- **Background tasks:** FastAPI `BackgroundTasks` are not reliable in Lambda because the execution environment may be frozen after the response is returned. Use SQS, Step Functions, EventBridge, or asynchronous Lambda invocation instead. [reddit](https://www.reddit.com/r/FastAPI/comments/1e6aucl/architecture_question/)

## My recommendation

For a typical REST API with variable or low-to-medium traffic, I would start with **FastAPI + Mangum + API Gateway HTTP API**, deployed through **AWS SAM**. It is simple, inexpensive at low traffic, and keeps your application logic mostly cloud-agnostic. [builder.aws](https://builder.aws.com/content/3KHzA4aOtupX6ZZg04EwGFUpRX4/deploy-fastapi-to-aws-lambda-in-minutes)
