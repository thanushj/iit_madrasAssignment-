from fastapi import FastAPI
from contextlib import asynccontextmanager

from app.db.database import Base, engine
import app.models  # VERY IMPORTANT

from app.api.routes import auth


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Creating tables...")
    Base.metadata.create_all(bind=engine)
    print("✅ Done")
    yield


app = FastAPI(title="Bug Tracker API", lifespan=lifespan)

app.include_router(auth.router)


@app.get("/health")
def health():
    return {"status": "ok"}
