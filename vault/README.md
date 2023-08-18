# VAULT.md

## Prerequisites
- Docker installed on your machine.
- Basic understanding of Docker and HashiCorp Vault.

## Launching the Containers

Once the docker-compose.yml is ready, run the following command in the same directory to start the containers:

```bash
docker-compose up -d
```

## Setup

Follow the steps below to stand up a HashiCorp Vault container:

## Docker Compose File

Ideally you would create a docker-compose.yml file with the following content:

```yaml
version: "3.7"
services:
  vault:
    image: vault:1.4.2
    container_name: vault
    hostname: vault
    ports:
      - 8200:8200
    volumes:
      - ./config.hcl:/vault/config/config.hcl
      - vault-data:/vault/file/
    environment:
      - VAULT_ADDR=http://localhost:8200
    cap_add:
      - IPC_LOCK
    command: server
    restart: always

  vault-init:
    image: vault:1.4.2
    container_name: vault-init
    environment:
      - VAULT_ADDR=http://vault:8200
      - MY_VAULT_TOKEN=${MY_VAULT_TOKEN:-test}
    volumes:
      - ./vault-root-token:/vault/file/vault-root-token
      - ./vault-init.sh:/usr/local/bin/vault-init.sh
      - vault-data:/vault/file/
    command: /usr/local/bin/vault-init.sh
    restart: on-failure
    depends_on:
      - vault

volumes:
  vault-data:
```

The purpose of this container is to quickly get your vault instance running. Don't worry about root keys as the init container will help facilitate this process. Just to get started, just use 1 to answer both questions. If you need to migrate content, you can at a later time once you've become acquainted with the vault container.

This file defines two services: vault and vault-init. The vault service runs the Vault server, and the vault-init service is responsible for initializing the vault.

### config.hcl

Create a file named `config.hcl` at the same level as your docker-compose.yml

```HCL
ui = true

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

storage "file" {
  path = "/vault/file"
}

api_addr = "http://127.0.0.1:8200"

disable_mlock = "true"
```

> All other pertinent files will be created and adjusted appropriately. Please review the volume mounts within the docker compose.

## Access the Vault Container

After the container is running, you can interact with the Vault server using the Vault CLI or API. The Vault server is accessible at `http://<local ip>:8200`.

## Checking Vault Status

You can check the status of the vault by running:

```bash
docker exec -it vault vault status
```

-------------------------------------------------------------------------------

## Next Steps

[Steps to setup VAULT](VAULT-SETUP.md)
