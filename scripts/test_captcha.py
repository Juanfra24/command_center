"""
Test captcha handling on account.jagex.com.
Run WITHOUT proxy to check if the mechanism works,
then debug why it fails with a proxy.
"""
import sys
import time
import os

# Add --debug to enable SeleniumBase's internal debug prints
if "--debug" not in sys.argv:
    sys.argv.append("--debug")

try:
    import pyautogui
    print(f"[OK] PyAutoGUI {pyautogui.__version__} - screen {pyautogui.size()}")
except ImportError:
    print("[FAIL] pyautogui not installed! Run: pip install pyautogui")
    sys.exit(1)

from seleniumbase import SB
import seleniumbase
print(f"[OK] SeleniumBase {seleniumbase.__version__}")

URL = "https://account.jagex.com/"

print(f"\n[INFO] Starting browser...")

with SB(
    uc=True,
    headless=False,
    page_load_strategy="eager",
    incognito=True,
) as sb:
    print("[INFO] Browser started")

    # Step 1: Open with reconnect (this is how SeleniumBase recommends handling CF)
    print(f"[INFO] uc_open_with_reconnect('{URL}', reconnect_time=6)...")
    sb.uc_open_with_reconnect(URL, reconnect_time=6)
    time.sleep(1)

    title = sb.get_title()
    print(f"[INFO] Page title: '{title}'")
    print(f"[INFO] Current URL: {sb.get_current_url()}")

    # Check page source for CF indicators
    source = sb.get_page_source()
    cf_indicators = {
        "cf-turnstile-": "cf-turnstile-" in source,
        "challenge-platform": "/challenge-platform/" in source,
        "challenge-widget": 'id="challenge-widget-' in source,
        "challenges.cloudf": "challenges.cloudf" in source,
        "onCaptchaSuccess": 'onCaptchaSuccess' in source,
        "#challenge-stage": sb.is_element_present("#challenge-stage"),
        "#challenge-form": sb.is_element_present("#challenge-form"),
        "iframe": sb.is_element_present("iframe"),
        ".cf-turnstile-wrapper": sb.is_element_present(".cf-turnstile-wrapper"),
        "Are you a robot": "are you a robot" in source.lower(),
        "Verify you are human": "verify you are human" in source.lower(),
    }
    print("\n[INFO] CF Turnstile indicators found:")
    for k, v in cf_indicators.items():
        if v:
            print(f"  [YES] {k}")
        else:
            print(f"  [ - ] {k}")

    is_cf_page = any(cf_indicators.values())

    if is_cf_page:
        print("\n[INFO] Cloudflare challenge detected! Testing captcha click...")

        # Method 1: uc_gui_click_captcha (auto-detect)
        print("\n[TEST 1] sb.uc_gui_click_captcha()...")
        try:
            sb.uc_gui_click_captcha()
            print("[OK] uc_gui_click_captcha completed")
        except Exception as e:
            print(f"[FAIL] {type(e).__name__}: {e}")

        time.sleep(4)
        title2 = sb.get_title()
        print(f"[INFO] Title after attempt 1: '{title2}'")

        if "just a moment" in title2.lower() or "robot" in sb.get_page_source().lower():
            print("[INFO] Still on CF page. Trying method 2...")

            # Method 2: Reload and try uc_gui_click_cf (Cloudflare-specific)
            sb.uc_open_with_reconnect(URL, reconnect_time=8)
            time.sleep(2)

            print("\n[TEST 2] sb.uc_gui_click_cf()...")
            try:
                sb.uc_gui_click_cf()
                print("[OK] uc_gui_click_cf completed")
            except Exception as e:
                print(f"[FAIL] {type(e).__name__}: {e}")

            time.sleep(4)
            title3 = sb.get_title()
            print(f"[INFO] Title after attempt 2: '{title3}'")

            if "just a moment" in title3.lower() or "robot" in sb.get_page_source().lower():
                print("[INFO] Still on CF page. Trying method 3...")

                # Method 3: Reload and try uc_gui_handle_captcha
                sb.uc_open_with_reconnect(URL, reconnect_time=8)
                time.sleep(2)

                print("\n[TEST 3] sb.uc_gui_handle_captcha()...")
                try:
                    sb.uc_gui_handle_captcha()
                    print("[OK] uc_gui_handle_captcha completed")
                except Exception as e:
                    print(f"[FAIL] {type(e).__name__}: {e}")

                time.sleep(4)
                title4 = sb.get_title()
                print(f"[INFO] Title after attempt 3: '{title4}'")
            else:
                print("[OK] Captcha solved with method 2!")
        else:
            print("[OK] Captcha solved with method 1!")
    else:
        print("[INFO] No CF challenge detected - page loaded directly")

    print(f"\n[INFO] Final title: '{sb.get_title()}'")
    print(f"[INFO] Final URL: {sb.get_current_url()}")
    print("\n[INFO] Keeping browser open for 15s...")
    time.sleep(15)
    print("[INFO] Done.")
