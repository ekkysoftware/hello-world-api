from fastapi import FastAPI
from mangum import Mangum

app = FastAPI()


@app.get("/")
def hello():
    return {"message": "hello"}


# AWS Lambda entrypoint: Lambda console/CLI handler is "main.handler".
handler = Mangum(app)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
