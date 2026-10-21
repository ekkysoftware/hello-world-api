from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def hello():
    return {"message": "hello"}

if __name__ == "__main__":
    app()
