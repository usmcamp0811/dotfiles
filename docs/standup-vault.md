# How to stand-up Vault in a New Environment

This tutorial is how to create a new system and install Vault on it so that
we can get other systems to work. This will assume that all that has been
installed is a blank NixOS system, real or virtual. This also assumes
you are using [this repo](https://gitlab.com/usmcamp0811/dotfiles.git) or at least a fork or some derivation of this repo.

## Step 1. Deploy Barebones Archetype

If this is a new system that doesn't already exist in these dotfiles then
we need to create it in `./systems/x86_64-linux/<system hostname>` or
if its not `x86_64-linux` use the correct architecture name. I have a
template for this scenario. After creating the directory just `cd`
into it and run:

```sh
nix flake init --template gitlab:usmcamp0811/dotfiles#new-system
# or if its an Azure VM or some other Virtual Machine maybe try
nix flake init --template gitlab:usmcamp0811/dotfiles#new-azure-vm
```

> Note: You can probably add `campground.services.vault` to the system
> config now otherwise after you deploy add it and deploy again.

To deploy the system we can use `deploy-rs` to get the system config to
the new machine. This is super useful if your system is slow such as when
its a 2 threaded VM. I have a Nix shell I have created that should have
all the things you need already pre-loaded into it. The rest of this
tutorial will assume you are in it. To activate this shell just run the
following command:

```sh
nix develop gitlab:usmcamp0811/dotfiles#deploy-shell
```

**Deploying Barebones config (+ Vault):**

```
deploy --hostname <ip|hostname> --skip-checks /location/of/flake#<new system hostname>
```

> NOTE: If you have problems with the deploy command you may want to try running
> it with `--ssh-user <your user on the remote machine>`. This is because my
> flake defaults to `root` and as seen [here](https://gitlab.com/usmcamp0811/dotfiles/-/blob/nixos/lib/deploy/default.nix?ref_type=heads#L46)

## Step 2. Initialize & Unseal Vault

Excellent! You now have a new system running. Now lets get Vault setup. I am
assuming you deployed Vault to the system above. The following can be run
in the `deploy-shell` anywhere that can reach the newly deployed Vault.

```sh
# to see options pass
# vault-init --help
vault-init
```

> NOTE: If you are running this anywhere other than on the system that has Vault
> running on it you **MUST** set `VAULT_ADDR` with the correct location of Vault.

This script will initialize Vault with a single root token and a single unseal key, which are necessary
for managing and accessing the Vault. The unseal key is required to "unlock" the Vault after it starts,
enabling it to decrypt and serve stored secrets, while the root token provides full administrative
access. The `init-vault` script will securely save these credentials to predefined or user-specified
file paths, ensuring they are available for future use. Once initialized, the script will automatically
unseal the Vault, making it ready to store and retrieve secrets. This simplifies the process of setting
up Vault in a new environment and ensures it is properly configured for secure operations. You are
free to re-key the Vault at anytime if your security posture changes and desire more than a single
root token.

## Step 3. Accessing Vault UI and Configuring Vault

Now that Vault has been initialized we probably want to be able to access our Vault from
the WebUI. By default in my config it can be reached from `http://0.0.0.0:8200` but if you
passed different options to the module when enabling it in your new system, you should use
that `hostname` or `ip`. In other tutorials I will cover how to setup Traefik so we
can use more human readable addresses.

### Vault UI

**In a web browser** navigate to [http://new-server-ip:8200](http://new-server-ip:8200). If
everything went well you should be presented with the Vault Login page that looks something
like this:

![Vault Login](./vault-login.png)

Use your root token, found by default at `/var/lib/vault/root-token`, to login.
Once in you can create your KV stores how ever you would like. I have mine setup
with a KV version 2 store at `secret/campground`. You don't need the UI to do this
it can be done with the following shell command, done somewhere that has `VAULT_ADDR`
set correctly and is logged into Vault.

### Adding Secrets with the CLI

```sh
# in nix develop gitlab:usmcamp0811/dotfiles#deploy-shell

export VAULT_ADDR=http://my-new-hostname:8200
vault login

# provide root token
vault secrets enable -path=secret/mydomain -version=2 kv

# confirm its creation
vault secrets list

# add secrets
vault kv put secret/mydomain/mysecret key1=value1 key2=value2
```

> **⚠️ WARNING:** Secrets entered via the Vault CLI may be saved in your shell history.
> To protect sensitive data, consider using environment variables or other secure methods
> to input secrets.

### Adding Policies

## Step 4. Configuring NixOS system to use Vault

Great
