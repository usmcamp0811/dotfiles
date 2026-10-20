---
type: NixOS Module
title: Nostalgex web tuner (fmf.services.nostalgex)
description: Serves the Nostalgex web tuner, a retro cable-TV channel guide for a Plex, Jellyfin or Emby library, with Nginx.
resource: ./default.nix
tags: [services, nostalgex]
---

# Nostalgex web tuner (`fmf.services.nostalgex`)

Serves the [Nostalgex](https://www.nostalgex.app/self-host) web tuner, a retro
cable-TV channel guide for a Plex, Jellyfin or Emby library, with Nginx. It is
the same set of static files upstream's Docker image serves, from
`pkgs.fmf.nostalgex` (`packages/applications/nostalgex`). There is no backend,
database, secret or state: the tuner runs in the browser and talks directly to
your media server.

## Why run it yourself

The hosted tuner is https, and a browser will not let an https page call a plain
`http://` media server. Serving the tuner over plain http on the same network
removes that wall for a Jellyfin or Emby on a LAN address. If your media server is
already behind https with a valid certificate, or you use Plex (plex.direct gives
it one), the hosted tuner already works and you do not need this.

## Quick start

Put it on the same host as Jellyfin:

```nix
{
  fmf.services = {
    jellyfin.enable = true;
    nostalgex = {
      enable = true;
      openFirewall = true;
    };
  };
}
```

Open `http://<machine-ip>:8080` in a browser on the same network and connect to
your server the same way you would on the hosted tuner. Use the media server's
plain `http://` address.

## Options

All options below are under `fmf.services.nostalgex`.

| Option | Default | Purpose |
| --- | --- | --- |
| `enable` | `false` | Serve the tuner with Nginx |
| `package` | `pkgs.fmf.nostalgex` | Package to serve; override to build with Supabase values |
| `port` | `8080` | Port to listen on |
| `listenAddress` | `"0.0.0.0"` | Address to listen on |
| `domain` | `"_"` | Nginx `server_name`; the default answers on any address or hostname |
| `openFirewall` | `false` | Open `port` in the firewall |
| `enrichment` | `false` | Let the tuner fetch TMDB/IMDb metadata (see below) |

The module enables `services.nginx` and adds one virtual host. Other fmf sites
that use Nginx on the same machine (`matt-camp-website`, `nix-slide-website`) are
unaffected as long as each listens on its own port.

## What it serves

The module reproduces upstream's `docker/nginx.conf`:

- `.cjs` is served as JavaScript. Nginx has no type for it, and with `nosniff` a
  wrong type blocks `scripts/nostalgex-channel-filter.cjs` and breaks the library
  load. The rest of the stock MIME table is kept.
- Security headers on every response: `nosniff`, `X-Frame-Options`,
  `Referrer-Policy`, `Permissions-Policy` and a Content-Security-Policy that allows
  http and https media servers. There is no HSTS, on purpose.
- Pages, `channels.json` and the helper scripts are never cached (`expires -1`).
  `/assets/` (hashed names) is cached for a year and `/vendor/` for a week.
- `/healthz` returns `ok`.
- `/config.json` is rendered by the module (below), not taken from the package.
- Relative redirects and no server version in headers.

## Metadata enrichment

About nine channels (TEEN MOVIES, TRUE CRIME, CULT CLASSICS and others) need
keywords, studios or IMDb ratings that Plex, Jellyfin and Emby do not provide.
With enrichment on, the browser reads them from a shared Supabase cache and the
nostalgex.app TMDB/OMDb relay. Only TMDB and IMDb ids are sent: no titles, server
address or credentials. Everything else in the tuner makes no outside request
(no CDN, fonts or analytics are loaded), apart from `plex.tv` for Plex sign-in.

It takes two things, and both are needed:

1. `fmf.services.nostalgex.enrichment = true;` writes `"enrichment": true` into
   `/config.json`. Upstream's image defaults to on; this module defaults to **off**
   so nothing leaves the network unless you ask. Anything other than `true` makes
   the tuner send no enrichment request, even if the file cannot be read.
2. The package needs a Supabase URL and anon key baked into the page at build time.
   Upstream's published image has its own; they are not in the source repository.
   Use your own Supabase project (the anon key is public by design) or ask upstream:

   ```nix
   {
     fmf.services.nostalgex = {
       enable = true;
       enrichment = true;
       package = pkgs.fmf.nostalgex.override {
         supabaseUrl = "https://<project>.supabase.co";
         supabaseAnonKey = "<anon key>";
       };
     };
   }
   ```

   The anon key ends up in the Nix store and in the served page. Do not use a
   service-role key.

Turning `enrichment` on with a package built without those values only produces an
evaluation warning; the tuner still works, those channels just stay empty.

## Behind a reverse proxy

Serve the tuner and your media server **the same way**. If the tuner is behind
https and Jellyfin is still plain http, the browser blocks Jellyfin again for the
exact reason this module exists. Plain http for both is the simple setup. If you
want https, put both behind it.

## Verifying

```bash
curl -s http://<host>:8080/healthz                 # ok
curl -s http://<host>:8080/config.json
curl -sI http://<host>:8080/scripts/nostalgex-channel-filter.cjs | grep -i content-type
systemctl status nginx
```

A NixOS VM test covers the MIME types, headers, caching, `config.json`, the health
check and the firewall behaviour:

```bash
nix build .#checks.x86_64-linux.nostalgex -L
```

## Updating

Bump `version`, the source `hash` and `npmDepsHash` in
`packages/applications/nostalgex/default.nix`. Upstream tags the tuner as
`tuner-v*` (the `v*` tags are the Apple TV app). Get the hashes with
`nix flake prefetch github:chadMueller/Nostalgex/tuner-v<version>` and
`prefetch-npm-deps package-lock.json` against that tag's lockfile.

## License

Nostalgex is MIT licensed. The Nostalgex name, icon and the nostalgex.app site are
not part of that grant.
