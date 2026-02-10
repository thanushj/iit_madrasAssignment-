from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional
from datetime import datetime

class ProjectCreate(BaseModel):
    name: str = Field(..., max_length=100)
    description: Optional[str] = Field(None, max_length=1000)

class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = Field(None, max_length=1000)
    is_archived: Optional[bool]

class ProjectResponse(BaseModel):
    id: UUID
    name: str
    description: Optional[str]
    created_by: UUID
    created_at: datetime
    updated_at: datetime
    is_archived: bool
    class Config: from_attributes = True
