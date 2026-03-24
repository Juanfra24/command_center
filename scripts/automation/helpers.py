# scripts/automation/helpers.py
import re
import json
import asyncio
import random
import string
import secrets
from datetime import datetime
from typing import Optional, List

from patchright.async_api import Page


async def human_type(page: Page, selector: str, text: str,
                     min_delay: float = 30, max_delay: float = 120):
    """Type text character-by-character with human-like delays.
    Delays are in milliseconds (Playwright convention)."""
    await page.click(selector)
    await page.type(selector, text, delay=random.uniform(min_delay, max_delay))


async def click_first_match(page: Page, selectors: List[str],
                            timeout: int = 5000, label: str = "",
                            log_fn=print) -> bool:
    """Try clicking each selector in order; return True on first success.
    timeout is in milliseconds."""
    for sel in selectors:
        try:
            await page.click(sel, timeout=timeout)
            if label:
                log_fn(f"[INFO] {label} with: {sel}")
            return True
        except Exception:
            continue
    return False


async def human_delay(min_sec: float = 0.5, max_sec: float = 2.0):
    """Sleep for a random duration to mimic human behavior."""
    await asyncio.sleep(random.uniform(min_sec, max_sec))


def extract_ip_from_response(text: str) -> Optional[str]:
    """Extract IP address from JSON API response text."""
    try:
        data = json.loads(text)
        for key in ("ip", "origin", "query"):
            if key in data:
                val = data[key]
                if isinstance(val, str):
                    return val.split(",")[0].strip()
    except Exception:
        pass
    match = re.search(r"\d{1,3}(?:\.\d{1,3}){3}", text)
    return match.group() if match else None


def generate_account_name() -> str:
    """Generate a gaming-style account name like SwiftArcher42."""
    adjectives = [
        "Dark", "Shadow", "Iron", "Swift", "Storm", "Frost", "Wild", "Steel",
        "Brave", "Silent", "Noble", "Fierce", "Crimson", "Ancient", "Mystic",
        "Golden", "Chaos", "Void", "Ember", "Ash", "Stone", "Rune", "Blood",
    ]
    nouns = [
        "Knight", "Mage", "Archer", "Blade", "Wolf", "Dragon", "Hunter",
        "Slayer", "Warrior", "Ranger", "Guard", "Titan", "Phoenix", "Hawk",
        "Bear", "Viper", "Sage", "Reaper", "Lord", "King", "Rogue", "Scout",
    ]
    name = random.choice(adjectives) + random.choice(nouns)
    if random.random() < 0.7:
        name += str(random.randint(10, 999))
    return name


def generate_email(account_name: str) -> str:
    """Derive email from account name: e.g., swiftarcher42@onemanco.org"""
    clean = re.sub(r"[^a-zA-Z0-9]", "", account_name).lower()
    return f"{clean}@onemanco.org"


def generate_password() -> str:
    """Generate a strong password meeting Jagex requirements (12-16 chars)."""
    length = random.randint(12, 16)
    chars = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice("!@#$%^&*"),
    ]
    remaining = length - len(chars)
    pool = string.ascii_letters + string.digits + "!@#$%^&*"
    chars += [secrets.choice(pool) for _ in range(remaining)]
    random.shuffle(chars)
    return "".join(chars)


def generate_random_dob() -> dict:
    """Generate random DOB (18-35 years old). Zero-padded for DD/MM fields."""
    current_year = datetime.now().year
    year = random.randint(current_year - 35, current_year - 18)
    month = random.randint(1, 12)
    day = random.randint(1, 28)
    return {"day": str(day).zfill(2), "month": str(month).zfill(2), "year": str(year)}


IP_CHECK_URLS = [
    "https://api.ipify.org?format=json",
    "https://httpbin.org/ip",
    "https://api.myip.com",
]
