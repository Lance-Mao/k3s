from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import os

app = FastAPI(title="K3s Demo API")

# Track pod start time
START_TIME = datetime.now()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_uptime():
    """Calculate uptime since pod started"""
    delta = datetime.now() - START_TIME
    total_seconds = int(delta.total_seconds())
    
    days = total_seconds // 86400
    hours = (total_seconds % 86400) // 3600
    minutes = (total_seconds % 3600) // 60
    seconds = total_seconds % 60
    
    if days > 0:
        return f"{days}d {hours}h"
    elif hours > 0:
        return f"{hours}h {minutes}m"
    elif minutes > 0:
        return f"{minutes}m {seconds}s"
    else:
        return f"{seconds}s"

@app.get("/")
def root():
    return {
        "message": "Hello from K3s! 🚀",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "timestamp": datetime.now().isoformat(),
        "hostname": os.getenv("HOSTNAME", "unknown"),
        "replicas": os.getenv("REPLICAS", "2"),
        "deploy_count": os.getenv("DEPLOY_COUNT", "1"),
        "environment": os.getenv("ENVIRONMENT", "production"),
        "uptime": get_uptime(),
        "started_at": START_TIME.isoformat()
    }

@app.get("/health")
def health():
    return {"status": "healthy", "uptime": get_uptime()}

@app.get("/ready")
def ready():
    return {"status": "ready"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
