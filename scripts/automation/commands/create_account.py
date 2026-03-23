# scripts/automation/commands/create_account.py
import asyncio
import random
import sys
from typing import Optional, Callable

from ..models import AutomationResult, AutomationStatus
from ..proxy import preflight_proxy
from ..browser import launch_browser, close_browser
from ..helpers import (
    human_type, click_first_match, human_delay,
    extract_ip_from_response,
    generate_account_name, generate_email, generate_password, generate_random_dob,
)
from ..imap_poller import fetch_verification_code

IP_CHECK_URLS = [
    "https://api.ipify.org?format=json",
    "https://httpbin.org/ip",
    "https://api.myip.com",
]


async def _is_past_cloudflare(page, log_fn) -> bool:
    """Check if we've passed the Cloudflare challenge."""
    try:
        title = await page.title()
        if "just a moment" in title.lower():
            return False

        content = await page.content()
        content_lower = content.lower()

        cf_indicators = ["are you a robot", "verify you are human", "checking your browser"]
        if any(kw in content_lower for kw in cf_indicators):
            return False

        jagex_indicators = [
            "create an account", "registration", "log in",
            "jagex account", 'id="email"',
        ]
        return any(kw in content_lower for kw in jagex_indicators)
    except Exception:
        return False


async def _handle_turnstile(page, log_fn, max_attempts: int = 5) -> bool:
    """Attempt to pass Cloudflare Turnstile challenge."""
    for attempt in range(1, max_attempts + 1):
        log_fn(f"[INFO] Turnstile attempt {attempt}/{max_attempts}")

        if await _is_past_cloudflare(page, log_fn):
            log_fn("[INFO] Already past Cloudflare")
            return True

        human_delay(1.0, 2.0)

        # Try to find and click the Turnstile checkbox inside its iframe
        try:
            turnstile_frame = page.frame_locator(
                "iframe[src*='challenges.cloudflare.com']"
            )
            checkbox = turnstile_frame.locator("input[type='checkbox'], .cb-lb")
            await checkbox.click(timeout=5000)
            log_fn("[INFO] Clicked Turnstile checkbox")
        except Exception as e:
            log_fn(f"[WARNING] Turnstile click failed: {e}")
            # Fallback: try clicking body of iframe
            try:
                turnstile_frame = page.frame_locator(
                    "iframe[src*='challenges.cloudflare.com']"
                )
                await turnstile_frame.locator("body").click(timeout=3000)
                log_fn("[INFO] Clicked Turnstile iframe body")
            except Exception:
                pass

        # Wait for verification
        log_fn("[INFO] Waiting for Turnstile verification...")
        human_delay(5.0, 8.0)

        if await _is_past_cloudflare(page, log_fn):
            log_fn("[INFO] Turnstile solved!")
            return True

        # Retry: reload the page
        if attempt < max_attempts:
            log_fn("[INFO] Reloading page for retry...")
            try:
                await page.goto("https://account.jagex.com/", wait_until="domcontentloaded")
                human_delay(3.0, 5.0)
            except Exception:
                pass

    return False


async def create_account(
    proxy_url: Optional[str],
    expected_ip: str,
    headless: bool = False,
    debug: bool = False,
    imap_host: Optional[str] = None,
    imap_user: Optional[str] = None,
    imap_pass: Optional[str] = None,
    log_fn: Callable[[str], None] = print,
) -> AutomationResult:
    """Create a new Jagex account through the proxy."""
    log_fn("[INFO] ===== Account Creation =====")

    err, cleaned_proxy = preflight_proxy(proxy_url, expected_ip, log_fn)
    if err:
        return err

    account_name = generate_account_name()
    generated_email = generate_email(account_name)
    generated_password = generate_password()
    dob = generate_random_dob()
    log_fn(f"[INFO] Account: {account_name}, Email: {generated_email}")
    log_fn(f"[INFO] DOB: {dob['day']}/{dob['month']}/{dob['year']}")

    pw = browser = None
    try:
        pw, browser, context, page = await launch_browser(
            proxy_url=cleaned_proxy,
            headless=headless,
        )
        log_fn("[INFO] Browser started for account creation")

        # Step 1: Validate proxy IP
        log_fn("[STEP 1/13] Validating proxy IP...")
        actual_ip = None
        for i, url in enumerate(IP_CHECK_URLS):
            try:
                await page.goto(url, wait_until="domcontentloaded")
                human_delay(1.0, 2.0)
                body = await page.text_content("body") or ""
                actual_ip = extract_ip_from_response(body)
                if actual_ip:
                    log_fn(f"[STEP 1/13] Got IP: {actual_ip}")
                    break
            except Exception as e:
                log_fn(f"[WARNING] IP check failed: {e}")

        if not actual_ip:
            log_fn("[STEP 1/13] FAILED - could not determine IP")
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message="Could not determine current IP",
                expected_ip=expected_ip,
            )

        if not (actual_ip.strip() == expected_ip.strip()):
            log_fn(f"[STEP 1/13] FAILED - IP mismatch: expected {expected_ip}, got {actual_ip}")
            return AutomationResult(
                status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                message=f"IP mismatch: expected {expected_ip}, got {actual_ip}",
                expected_ip=expected_ip, actual_ip=actual_ip,
            )
        log_fn(f"[STEP 1/13] OK - proxy IP validated: {actual_ip}")

        # Step 2: Navigate to Jagex
        log_fn("[STEP 2/13] Navigating to account.jagex.com...")
        await page.goto("https://account.jagex.com/", wait_until="domcontentloaded")
        human_delay(2.0, 3.0)

        # Step 3: Handle Cloudflare Turnstile
        log_fn("[STEP 3/13] Handling Cloudflare Turnstile...")
        if not await _handle_turnstile(page, log_fn):
            log_fn("[STEP 3/13] FAILED - could not pass Cloudflare Turnstile")
            return AutomationResult(
                status=AutomationStatus.CAPTCHA_REQUIRED.value,
                message="Could not pass Cloudflare Turnstile after all attempts",
                expected_ip=expected_ip, actual_ip=actual_ip,
            )

        # Step 4: Handle cookie consent
        log_fn("[STEP 4/13] Handling cookie consent...")
        cookie_selectors = [
            "#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll",
            "button#CybotCookiebotDialogBodyButtonDecline",
            "//button[contains(text(), 'Use necessary cookies only')]",
            "//button[contains(text(), 'Allow all cookies')]",
        ]
        await click_first_match(page, cookie_selectors, timeout=3000, label="Cookie consent handled", log_fn=log_fn)
        human_delay(1.0, 2.0)

        # Step 5: Click 'Create an account'
        log_fn("[STEP 5/13] Clicking 'Create an account'...")
        create_selectors = [
            "a[href*='registration']",
            "text=Create an account",
            "text=create an account",
            "a.create-account-link",
        ]
        created = await click_first_match(page, create_selectors, timeout=5000, label="Create account clicked", log_fn=log_fn)
        if created:
            human_delay(2.0, 3.0)
        else:
            log_fn("[WARNING] Could not find link, trying direct URL")
            await page.goto("https://account.jagex.com/en-GB/login/registration-start", wait_until="domcontentloaded")
            human_delay(2.0, 3.0)

        # Step 6: Fill email
        log_fn("[STEP 6/13] Filling email...")
        email_selectors = [
            "input[name='email']", "input[type='email']",
            "input[placeholder*='email' i]", "#email",
        ]
        email_filled = False
        for sel in email_selectors:
            try:
                await page.wait_for_selector(sel, timeout=8000, state="visible")
                await human_type(page, sel, generated_email)
                log_fn(f"[INFO] Email filled with: {sel}")
                email_filled = True
                break
            except Exception:
                continue

        if not email_filled:
            log_fn("[STEP 6/13] FAILED - could not find email field")
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message="Could not find or fill the email field",
                expected_ip=expected_ip, actual_ip=actual_ip,
            )

        # Step 7: Fill DOB
        log_fn("[STEP 7/13] Filling DOB...")
        dob_fields = [
            (["input[placeholder='DD']", "input[name='dobDay']", "input[name='day']", "input[aria-label*='day' i]"], dob["day"]),
            (["input[placeholder='MM']", "input[name='dobMonth']", "input[name='month']", "input[aria-label*='month' i]"], dob["month"]),
            (["input[placeholder='YYYY']", "input[name='dobYear']", "input[name='year']", "input[aria-label*='year' i]"], dob["year"]),
        ]
        for selectors, value in dob_fields:
            filled = False
            for sel in selectors:
                try:
                    await page.wait_for_selector(sel, timeout=3000, state="visible")
                    # Triple-click to select any existing text, then type over it
                    await page.click(sel, click_count=3)
                    human_delay(0.1, 0.2)
                    await page.type(sel, value, delay=random.uniform(30, 80))
                    log_fn(f"[INFO] DOB field '{sel}' filled with '{value}'")
                    filled = True
                    break
                except Exception:
                    continue
            if not filled:
                log_fn(f"[STEP 7/13] FAILED - could not fill DOB value '{value}'")
                return AutomationResult(
                    status=AutomationStatus.BROWSER_ERROR.value,
                    message=f"Could not fill date of birth field (value: {value})",
                    expected_ip=expected_ip, actual_ip=actual_ip,
                )
            human_delay(0.2, 0.4)

        human_delay(0.5, 1.0)

        # Step 8: Accept terms
        log_fn("[STEP 8/13] Accepting terms...")
        terms_selectors = [
            "input[type='checkbox']", "label[for*='terms']",
            "label[for*='agree']", "text=I agree",
        ]
        await click_first_match(page, terms_selectors, timeout=3000, label="Terms accepted", log_fn=log_fn)
        human_delay(0.5, 1.0)

        # Step 9: Click Continue
        log_fn("[STEP 9/13] Clicking Continue...")
        continue_selectors = [
            "button[type='submit']", "text=Continue",
            "button.submit", "input[type='submit']",
        ]
        await click_first_match(page, continue_selectors, timeout=5000, label="Continue clicked", log_fn=log_fn)
        human_delay(3.0, 5.0)

        # Step 10: Email verification
        log_fn("[STEP 10/13] Email verification...")
        if imap_host and imap_user and imap_pass:
            code = await asyncio.to_thread(
                fetch_verification_code,
                imap_host, imap_user, imap_pass,
                generated_email, timeout=120, log_fn=log_fn,
            )
            if code:
                code_selectors = [
                    "input[name='code']", "input[type='text']",
                    "input[placeholder*='code' i]", "#code",
                ]
                for sel in code_selectors:
                    try:
                        await page.wait_for_selector(sel, timeout=10000, state="visible")
                        await human_type(page, sel, code, min_delay=50, max_delay=150)
                        log_fn(f"[INFO] Code entered with: {sel}")
                        human_delay(0.5, 1.0)
                        await click_first_match(page, [
                            "button[type='submit']", "text=Continue",
                            "text=Submit", "text=Verify",
                        ], timeout=5000, label="Verification submitted", log_fn=log_fn)
                        human_delay(3.0, 5.0)
                        break
                    except Exception:
                        continue
            else:
                log_fn("[STEP 10/13] FAILED - could not fetch verification code within timeout")
                return AutomationResult(
                    status=AutomationStatus.UNKNOWN_ERROR.value,
                    message="Email verification code not received within timeout",
                    expected_ip=expected_ip, actual_ip=actual_ip,
                )
        else:
            log_fn("[WARNING] IMAP not configured, skipping email verification")

        # Step 11: Display name
        log_fn("[STEP 11/13] Setting display name...")
        name_selectors = [
            "input[name='displayName']", "input[name='display_name']",
            "input[name='username']", "input[placeholder*='name' i]",
        ]
        name_filled = False
        for sel in name_selectors:
            try:
                await page.wait_for_selector(sel, timeout=10000, state="visible")
                await human_type(page, sel, account_name)
                log_fn(f"[INFO] Display name entered with: {sel}")
                human_delay(0.5, 1.0)
                await click_first_match(page, [
                    "button[type='submit']", "text=Continue",
                    "text=Set", "text=Next",
                ], timeout=5000, label="Display name submitted", log_fn=log_fn)
                human_delay(3.0, 5.0)
                name_filled = True
                break
            except Exception:
                continue

        if not name_filled:
            log_fn("[STEP 11/13] FAILED - could not fill display name")
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message="Could not find or fill the display name field",
                expected_ip=expected_ip, actual_ip=actual_ip,
            )

        # Step 12: Set password
        log_fn("[STEP 12/13] Setting password...")
        pwd_selectors = [
            "input[name='password']", "input[type='password']", "#password",
        ]
        password_filled = False
        for sel in pwd_selectors:
            try:
                await page.wait_for_selector(sel, timeout=10000, state="visible")
                await human_type(page, sel, generated_password, min_delay=30, max_delay=100)
                log_fn(f"[INFO] Password entered with: {sel}")

                # Try confirm password
                confirm_selectors = [
                    "input[name='confirmPassword']", "input[name='confirm_password']",
                    "input[name='passwordConfirm']", "input[placeholder*='confirm' i]",
                ]
                for csec in confirm_selectors:
                    try:
                        await page.wait_for_selector(csec, timeout=5000, state="visible")
                        await human_type(page, csec, generated_password, min_delay=30, max_delay=100)
                        log_fn(f"[INFO] Confirm password entered with: {csec}")
                        break
                    except Exception:
                        continue

                human_delay(0.5, 1.0)
                await click_first_match(page, [
                    "button[type='submit']", "text=Continue",
                    "text=Set", "text=Submit",
                ], timeout=5000, label="Password submitted", log_fn=log_fn)
                human_delay(3.0, 5.0)
                password_filled = True
                break
            except Exception:
                continue

        if not password_filled:
            log_fn("[STEP 12/13] FAILED - could not fill password")
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message="Could not find or fill the password field",
                expected_ip=expected_ip, actual_ip=actual_ip,
            )

        # Step 13: Confirmation
        log_fn("[STEP 13/13] Checking for confirmation...")
        human_delay(2.0, 3.0)
        confirmed = False
        try:
            content = (await page.content()).lower()
            success_indicators = [
                "congratulations", "account created", "welcome",
                "success", "your account", "account is ready",
            ]
            confirmed = any(kw in content for kw in success_indicators)
        except Exception:
            pass

        dob_str = f"{dob['day']}/{dob['month']}/{dob['year']}"
        log_fn("[INFO] Account creation flow completed")
        result_data = {
            "email": generated_email,
            "password": generated_password,
            "accountName": account_name,
            "dob": dob_str,
            "confirmed": confirmed,
        }
        if confirmed:
            return AutomationResult(
                status=AutomationStatus.ACCOUNT_CREATED.value,
                message="Account created successfully",
                expected_ip=expected_ip,
                actual_ip=actual_ip,
                data=result_data,
            )
        else:
            return AutomationResult(
                status=AutomationStatus.UNKNOWN_ERROR.value,
                message="Account creation could not be confirmed",
                expected_ip=expected_ip,
                actual_ip=actual_ip,
                data=result_data,
            )

    except Exception as e:
        log_fn(f"[ERROR] Account creation failed at unexpected point: {type(e).__name__}: {e}")
        return AutomationResult(
            status=AutomationStatus.BROWSER_ERROR.value,
            message=f"Account creation failed: {type(e).__name__}: {e}",
            expected_ip=expected_ip,
        )
    finally:
        if browser and pw:
            await close_browser(pw, browser)
