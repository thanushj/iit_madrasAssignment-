from pydantic import BaseModel, EmailStr, Field
from enum import Enum
from uuid import UUID


class RoleEnum(str, Enum):
    developer = "developer"
    manager = "manager"
    admin = "admin"


class UserCreate(BaseModel):
    username: str = Field(..., max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=8)
    role: RoleEnum = RoleEnum.developer  # optional but recommended


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: UUID  # ✅ FIXED (was str before)
    username: str
    email: EmailStr
    role: RoleEnum

    class Config:
        from_attributes = True  # required for SQLAlchemy ORM
