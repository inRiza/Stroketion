from datetime import datetime

from pydantic import BaseModel, Field


class SosAlertCreate(BaseModel):
    message: str = Field(min_length=1, max_length=500)


class SosAlertResponse(BaseModel):
    id: str
    patient_id: str
    patient_name: str
    message: str
    created_at: datetime
