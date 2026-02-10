from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime

class CommentCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)

class CommentResponse(BaseModel):
    id: UUID
    content: str
    issue_id: UUID
    author_id: UUID
    created_at: datetime
    updated_at: datetime
    class Config: from_attributes = True
