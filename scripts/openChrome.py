import sys

from seleniumbase import SB

if __name__ == "__main__":
    if len(sys.argv) > 1:
        proxyUrl = sys.argv[1]  # 'your_argument' from Dart
    else:
        raise Exception("missing proxy argument")

    with SB(uc=True,proxy=proxyUrl if proxyUrl!="none" else "",) as sb:
        # Setting the driver path and requesting a page

        sb.driver.uc_open_with_reconnect("https://www.runescape.com/account_settings",180)
        sb.driver.quit()
        
