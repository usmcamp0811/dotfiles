"""
Create users in Authentik from a given list in a CSV file.

Requirements:
 - authentik_client: Install with `pip install authentik-client`

Usage:
 - Run the script with the CSV file path as an argument:
   `python create_users.py /path/to/user_list.csv`

CSV Format:
 - Each row should have the following columns:
   `firstname,surname,email,username,password,group`
 - Example:
   John,Doe,john.doe@example.com,johndoe,securepassword123,admins
"""

import csv
import sys
import argparse
from authentik_client import ApiClient, CoreApi, Configuration
from authentik_client.rest import ApiException


def import_user_list_csv(csv_path):
    try:
        with open(csv_path, newline="") as f:
            reader = csv.reader(f)
            return [list((e.strip() for e in row)) for row in reader]
    except FileNotFoundError:
        print(f"Error: File not found at {csv_path}")
        sys.exit(1)


def create_user(core_api, name, username, email):
    print(f"Creating user {username}...")
    api_response = core_api.core_users_create(
        user_request={"name": name, "username": username, "email": email}
    )
    print(f"Created user {api_response.username} with ID {api_response.pk}")
    return api_response.pk


def set_user_password(core_api, userid, password):
    print(f"Setting password for user ID {userid}...")
    core_api.core_users_set_password_create(
        id=userid, user_password_set_request={"password": password}
    )


def main(csv_path):
    # Update with your Authentik API configuration
    configuration = Configuration(
        host="https://your-authentik-instance/api/v3",
        access_token="your-api-token-here",
    )

    with ApiClient(configuration) as api_client:
        core_api = CoreApi(api_client)
        try:
            users = import_user_list_csv(csv_path)
            for firstname, surname, email, username, password, group in users:
                full_name = f"{firstname} {surname}"
                userid = create_user(core_api, full_name, username, email)
                set_user_password(core_api, userid, password)
        except ApiException as e:
            print(f"API Exception: {e}")
        except Exception as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create users in Authentik from a CSV file."
    )
    parser.add_argument("csv_path", help="Path to the CSV file containing user data.")
    args = parser.parse_args()

    main(args.csv_path)
