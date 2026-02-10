import uuid, enum
from sqlalchemy import Column, String, Text, Enum as SAEnum, Date, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.database import Base

class StatusEnum(str, enum.Enum):
    open = 'open'
    in_progress = 'in_progress'
    resolved = 'resolved'
    closed = 'closed'
    reopened = 'reopened'

class PriorityEnum(str, enum.Enum):
    low = 'low'
    medium = 'medium'
    high = 'high'
    critical = 'critical'

class Issue(Base):
    __tablename__ = 'issues'
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    status = Column(SAEnum(StatusEnum), default=StatusEnum.open)
    priority = Column(SAEnum(PriorityEnum), default=PriorityEnum.medium)
    project_id = Column(UUID(as_uuid=True), ForeignKey('projects.id', ondelete='CASCADE'), nullable=False)
    reporter_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='RESTRICT'), nullable=False)
    assignee_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    due_date = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
