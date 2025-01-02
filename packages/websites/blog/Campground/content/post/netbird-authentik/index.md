+++
author = "Matt Camp"
title = "Setting Up Authentik and Netbird with Nix"
date = "2025-01-01"
image = "netbird-network-routes.png"
description = "This post covers the setup of Authentik and Netbird using Nix, offering insights into the configuration process, pitfalls encountered, and solutions for a seamless integration. Learn how to manage secrets with Vault, configure essential services, and streamline your deployment with tips for Traefik and Cloudflare."
tags = [
    "Nix",
    "Authentik",
    "Netbird",
    "Traefik",
    "Cloudflare"
]
categories = [
    "Nix",
    "Networking",
    "DevOps",
]
+++

# Netbird & Authentik Setup

Setting up NetBird becomes straightforward once you know what you’re doing—but getting to that point
can be a pain. In case you’re not familiar, NetBird is an open-source, peer-to-peer VPN solution that
simplifies secure network connectivity. It uses WireGuard for encrypted communication and includes a
central management platform for configuration and access control. NetBird requires an identity provider,
and I chose [Authentik](https://goauthentik.io/) because [Keycloak](https://www.keycloak.org/) was
a total pain in the butt to set up and configure. Besides, Authentik is pretty neat and gets the job
done without the hassle.

## Authentik

The first step is to install Authentik. If you’re using my [dotfiles](https://gitlab.com/usmcamp0811/
dotfiles.git), this should be as simple as enabling it in your system’s configuration file. The module
is pretty straightforward and primarily leverages the stock service provided by
`github:nix-community/authentik-nix`.

To get it up and running, a few secrets are required. I manage these the same way I handle all my secrets
—using Vault and Vault-Agent to ensure they’re placed in the correct locations on the server. This process
is streamlined with a helper service I created, called `authentikSecrets`, which takes care of moving
the secrets where they need to be. Why? Because Authentik has five different services that all seem to
rely on the secrets—or at least might, who really knows?

```nix
services.authentik = {
  enable = true;
  environmentFile = "${authentikDir}/environmentFile";
  settings = {
    disable_startup_analytics = true;
    avatars = cfg.avatars;
  };
};
systemd.services.authentikSecrets = {
  description = "Get Authentik Secrets";
  serviceConfig = {
    Type = "oneshot";
    User = "root";
  };
  script = ''
    mkdir -p ${authentikDir}
    ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/environmentFile ${authentikDir}/environmentFile
  '';
  wantedBy = [ "multi-user.target" ];
  before = [
    "authentik-migrate.service"
    "authentik-worker.service"
    "authentik.service"
    "authentik-ldap.service"
    "authentik-radius.service"
  ];

};
```

I generated the `AUTHENTIK_SECRET_KEY` using a secure random generator, such as `openssl rand -base64 32`
or `python -c "import secrets; print(secrets.token_urlsafe(32))"`. Other required secrets are primarily
for configuring Authentik to send emails to users. In the future, I plan to explore fully automating
the setup of users and applications from an existing Authentik configuration. For now, this approach
works—stay tuned for a follow-up post where I’ll dive deeper into this process!

### Configuring Authentik

As noted earlier, configuring Authentik is a relatively straightforward process, especially when compared
to the complexities of Keycloak. To establish the foundational setup, start by creating a user in the
admin interface under `Directory` → `Users`. Next, navigate to the `Applications` section to define applications
, ensuring the correct provider and credentials are configured. For integrating with NetBird, I followed
[AuthentiK's official documentation](https://docs.goauthentik.io/integrations/services/netbird/) and [Netbird's official documentation](https://docs.netbird.io/selfhosted/identity-providers#authentik), which
was clear and easy to follow. To manage secrets, such as the service account password, I store them in
Vault under the NetBird KV, as they are currently only used for this integration.

## Netbird

As with most new tools, setting up Netbird with Nix involved some trial and error despite finding a few
examples online. While the documentation for Netbird provided a solid overview of its functionality,
the specifics of each subservice were not entirely clear—and, to be honest, they still aren't. However,
I’ve learned enough to get things running smoothly for now.

The **Management** service stands out as the most critical component. It uses `gRPC` and `TCP` protocols
and listens on a specific path rather than a subdomain. Similarly, the **Signal** service operates using
path prefixing rather than subpathing, much like the Management service. The **Dashboard**, on the other
hand, was a bit confusing. In the Nix module, it doesn’t have its own dedicated port, instead piggybacking
on the Management service.

Lastly, there’s the **Coturn** service, which appears to be optional but is recommended for better connectivity.
I haven’t managed to get this fully functional yet, likely due to a configuration issue with my router.

### Cloudflare Proxy Considerations

If you are using Cloudflare as a proxy, you need to enable the **gRPC passthrough** option for the Management
service to function correctly. For details on how to enable this, refer to [Cloudflare's gRPC passthrough
documentation](https://developers.cloudflare.com/network/grpc-connections/). Without this configuration, gRPC traffic will not be routed properly through Cloudflare.

When putting Netbird behind Traefik, many guides suggest additional routes and configurations. However,
the Nixpkgs team has simplified this by bundling a robust Nginx configuration with the service. By
enabling Nginx in the Nix module and pointing Traefik to the correct host and port, everything should
work seamlessly without needing extra proxy configurations.
