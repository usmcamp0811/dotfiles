# VAULT.md

## Prerequisites
- Docker installed on your machine.
- Basic understanding of Docker and HashiCorp Vault.

## Setup

Follow the steps below to stand up a HashiCorp Vault container:

1. **Pull the Vault Docker Image**

```shell
docker pull hashicorp/vault
```

2. **Run the Vault Container**

The command below starts a new container with the Vault image. The `-e` flags are used to configure the Vault server. 
`VAULT_DEV_ROOT_TOKEN_ID` sets the token for the root user, and `VAULT_DEV_LISTEN_ADDRESS` sets the address the Vault server will listen on.

```shell
docker run --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault
```

3. **Access the Vault Container**

After the container is running, you can interact with the Vault server using the Vault CLI or API. The Vault server is accessible at `http://localhost:8200`. To check the status of the Vault server, use:

```shell
docker exec -it <container_id> vault status
```

Replace `<container_id>` with your actual Vault Docker container ID.

## Note

This guide is meant to help you set up a simple Vault server in a Docker container for local development and testing. It's not suitable for production use. For a production setup, ensure Vault is properly secured and set up in a highly available configuration. For more information, refer to the [Vault Production Hardening guide](https://learn.hashicorp.com/tutorials/vault/production-hardening).
