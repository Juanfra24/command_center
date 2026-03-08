# scripts/automation/models.py
import json
from dataclasses import dataclass, asdict
from enum import Enum
from typing import Optional, Dict, Any


class AutomationStatus(Enum):
    SUCCESS = "success"
    PROXY_VALIDATION_FAILED = "proxy_validation_failed"
    BROWSER_ERROR = "browser_error"
    TIMEOUT = "timeout"
    CAPTCHA_REQUIRED = "captcha_required"
    ACCOUNT_CREATED = "account_created"
    UNKNOWN_ERROR = "unknown_error"


@dataclass
class AutomationResult:
    status: str
    message: str
    expected_ip: Optional[str] = None
    actual_ip: Optional[str] = None
    data: Optional[Dict[str, Any]] = None

    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=2)
