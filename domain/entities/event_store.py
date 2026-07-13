from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, Dict, Any

@dataclass
class DomainEvent:
    event_id: str
    aggregate_id: str
    aggregate_type: str
    event_type: str
    payload: Dict[str, Any]
    version: int = 1
    status: str = "Pending"  # Pending, Processing, Completed, Failed
    created_at: Optional[datetime] = None

@dataclass
class EventProcessing:
    id: Optional[str]
    event_id: str
    processor_name: str
    status: str  # Pending, Processing, Posted, Reversed, Cancelled, Failed
    processed_at: Optional[datetime] = None
    retry_count: int = 0
    error_message: Optional[str] = None
    created_at: Optional[datetime] = None
