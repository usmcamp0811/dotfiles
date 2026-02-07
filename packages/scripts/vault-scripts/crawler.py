#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3Packages.hvac
import os
import sys
import hvac
from getpass import getpass


def detect_kv_version(client, path):
    """
    Detect whether the secrets engine at the given path is KV v1 or v2.
    """
    try:
        # Try listing secrets with the KV v2 API
        client.secrets.kv.v2.list_secrets(path=path)
        return 2
    except hvac.exceptions.InvalidPath:
        try:
            # Try listing secrets with the KV v1 API
            client.secrets.kv.v1.list_secrets(path=path)
            return 1
        except hvac.exceptions.InvalidPath:
            return None


def crawl_vault_v1(client, path):
    """
    Crawl paths for KV v1 secrets engine.
    """
    try:
        list_response = client.secrets.kv.v1.list_secrets(path=path)
        keys = list_response["data"]["keys"]
    except hvac.exceptions.InvalidPath:
        return [path]

    all_keys = []
    for key in keys:
        if key.endswith("/"):
            sub_keys = crawl_vault_v1(client, f"{path}{key}")
            all_keys.extend(sub_keys)
        else:
            all_keys.append(f"{path}{key}")
    return all_keys


def crawl_vault_v2(client, path):
    """
    Crawl paths for KV v2 secrets engine.
    """
    try:
        list_response = client.secrets.kv.v2.list_secrets(path=path)
        keys = list_response["data"]["keys"]
    except hvac.exceptions.InvalidPath:
        return [path]

    all_keys = []
    for key in keys:
        if key.endswith("/"):
            sub_keys = crawl_vault_v2(client, f"{path}{key}")
            all_keys.extend(sub_keys)
        else:
            all_keys.append(f"{path}{key}")
    return all_keys


def generate_vault_commands(client, base_path):
    """
    Generate `vault kv put` commands for both KV v1 and v2 secrets engines.
    """
    kv_version = detect_kv_version(client, base_path)
    if not kv_version:
        print(f"Error: Unable to detect KV version for path: {base_path}")
        return []

    crawl_function = crawl_vault_v2 if kv_version == 2 else crawl_vault_v1
    all_kvs = crawl_function(client, base_path)
    commands = []

    for kv_path in all_kvs:
        try:
            if kv_version == 2:
                read_response = client.secrets.kv.v2.read_secret_version(
                    path=kv_path, raise_on_deleted_version=True
                )
                secret_data = read_response["data"]["data"]
            else:
                read_response = client.secrets.kv.v1.read_secret(path=kv_path)
                secret_data = read_response["data"]

            command = f"vault kv put {kv_path} " + " ".join(
                [f"{key}={{PLACEHOLDER}}" for key in secret_data.keys()]
            )
            commands.append(command)
        except hvac.exceptions.InvalidPath:
            continue

    return commands


if __name__ == "__main__":
    VAULT_ADDR = os.getenv("VAULT_ADDR")
    if not VAULT_ADDR:
        print("Error: VAULT_ADDR must be set as an environment variable.")
        exit(1)

    VAULT_TOKEN = os.getenv("VAULT_TOKEN")
    if not VAULT_TOKEN:
        VAULT_TOKEN = getpass("Enter your Vault token: ")

    if len(sys.argv) < 2:
        print("Usage: python script.py <base_path>")
        exit(1)

    BASE_PATH = sys.argv[1]

    client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)

    if not client.is_authenticated():
        print("Failed to authenticate with Vault. Please check your token.")
        exit(1)

    commands = generate_vault_commands(client, BASE_PATH)

    if commands:
        print("# Commands to recreate KV secrets with placeholders")
        for command in commands:
            print(command)
    else:
        print(f"No KV entries found under the path: {BASE_PATH}")
