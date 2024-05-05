# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`
import datetime
import json

import google.cloud.firestore
import pytz
import requests
from firebase_admin import firestore, initialize_app
from firebase_functions import scheduler_fn

app = initialize_app()
url = "https://proxy.webshare.io/api/v2/proxy/list/?mode=backbone&page=1&page_size=25"
api_token = "aknoovbazpr3g31w5fknz8i33y7q4crjviglym58"
headers = {"Authorization": f"Token {api_token}"}


class Proxy:
    def __init__(
        self,
        id,
        username,
        password,
        proxy_address,
        valid,
        last_verification,
        country_code,
        city_name,
        asn_name,
        asn_number,
        high_country_confidence,
        created_at,
        ip_timezone=None,
        linked_chars=None,
        hostname=None,
        port=80,
    ):
        self.id = id
        self.username = username
        self.password = password
        self.proxy_address = proxy_address
        self.hostname = hostname
        self.port = port
        self.valid = valid
        self.last_verification = Proxy._parse_datetime_to_utc(last_verification)
        ip_timezone = ip_timezone
        self.country_code = country_code
        self.linked_chars = linked_chars
        self.city_name = city_name
        self.asn_name = asn_name
        self.asn_number = asn_number
        self.high_country_confidence = high_country_confidence
        self.created_at = Proxy._parse_datetime_to_utc(created_at)

    @staticmethod
    def _parse_datetime_to_utc(date_str):
        """Parses a date string in the expected format (YYYY-MM-DDTHH:MM:SS.ffffffZ)
        and converts it to a datetime object in UTC."""
        # Assuming the original string is in the format mentioned above
        parsed_dt = datetime.datetime.fromisoformat(date_str)
        # Convert to UTC timezone

        local_tz = pytz.timezone("America/Los_Angeles")
        new_dt = parsed_dt.replace(tzinfo=local_tz).astimezone(pytz.utc)
        return new_dt

    def to_json(self):
        """Converts the Proxy object to a JSON string.

        Excludes id and port information by default.

        Returns:
          str: The JSON representation of the Proxy object.
        """
        # Convert datetime objects to strings in ISO format before serialization
        data = self.__dict__.copy()
        data["last_verification"] = data["last_verification"].isoformat()
        data["created_at"] = data["created_at"].isoformat()
        data["linked_chars"] = self.linked_chars
        return json.dumps(data, default=lambda obj: getattr(obj, "__name__", str(obj)))

    @classmethod
    def from_json(cls, json_data):
        """Creates a Proxy object from a JSON string.

        Args:
          json_data: str - The JSON string representing a Proxy object.

        Returns:
          Proxy: The Proxy object created from the JSON data.
        """

        return cls(**json_data)  # Unpack dictionary into constructor arguments


def get_timezone_from_ip(ip_address):
    """Fetches the timezone for a given IP address using ip-api.com.

    Args:
        ip_address: str - The IP address to query.

    Returns:
        str: The timezone string (e.g., "America/Toronto") or None if an error occurs.
    """

    url = f"http://ip-api.com/json/{ip_address}"
    try:
        response = requests.get(url)
        response.raise_for_status()  # Raise an exception for non-200 status codes

        data = response.json()
        if data["status"] == "success":
            return data["timezone"]
        else:
            print(
                f"Error retrieving data for IP: {ip_address}. Status: {data['status']}"
            )
            return None

    except requests.exceptions.RequestException as e:
        print(f"Error fetching data for IP: {ip_address}: {e}")
        return None


# Example usage
ip_address = "24.48.0.1"
timezone = get_timezone_from_ip(ip_address)


@scheduler_fn.on_schedule(
    schedule="0 * * * *",
    retry_count=2,
    timezone=scheduler_fn.Timezone("America/Santiago"),
)
def uploadproxies(event: scheduler_fn.ScheduledEvent) -> None:
    print(event.job_name)
    print(event.schedule_time)
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        data = response.json()
        proxies = [Proxy.from_json(item) for item in data["results"]]

    else:
        print(f"Error getting proxies: {response.status_code}")
        proxies = []

    firestore_client: google.cloud.firestore.Client = firestore.client()

    for proxy in proxies:
        proxy.hostname = "p.webshare.io"
        proxy.port = 80
        proxy.linked_chars = []
        proxy.ip_timezone = get_timezone_from_ip(proxy.proxy_address)
        json_data = proxy.to_json()
        try:
            firestore_client.collection("proxies").add(
                json.loads(json_data), proxy.proxy_address
            )
            print(f"Successfully uploaded proxy: {proxy.proxy_address}")
        except Exception as e:  # Catch general exceptions for better error handling
            print(f"Skipped proxy: {proxy.proxy_address}: {e}")

    print("Proxies were updated.")
    return
