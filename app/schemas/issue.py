from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional
from datetime import date, datetime
from app.models.issue import StatusEnum, PriorityEnum

class IssueCreate(BaseModel):
    title: str = Field(..., max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    priority: Optional[PriorityEnum] = PriorityEnum.medium
    assignee_id: Optional[UUID]
    due_date: Optional[date]

class IssueUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    status: Optional[StatusEnum]
    priority: Optional[PriorityEnum]
    assignee_id: Optional[UUID]
    due_date: Optional[date]

class IssueResponse(BaseModel):
    id: UUID
    title: str
    description: Optional[str]
    status: StatusEnum
    priority: PriorityEnum
    project_id: UUID
    reporter_id: UUID
    assignee_id: Optional[UUID]
    due_date: Optional[date]
    created_at: datetime
    updated_at: datetime
    class Config: from_attributes = True
