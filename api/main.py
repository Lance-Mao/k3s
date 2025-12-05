from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import os

app = FastAPI(title="K3s Demo API")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {
        "message": "Hello from K3s! 🚀",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "timestamp": datetime.now().isoformat(),
        "hostname": os.getenv("HOSTNAME", "unknown"),
        "replicas": os.getenv("REPLICAS", "2"),
        "deploy_count": os.getenv("DEPLOY_COUNT", "1"),
        "environment": os.getenv("ENVIRONMENT", "production")
    }

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.get("/ready")
def ready():
    return {"status": "ready"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

