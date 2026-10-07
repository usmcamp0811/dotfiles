# niks3 (Nix binary cache) — server, uploader, and access model

Modules involved:

| Module | Purpose |
|---|---|
| `fmf.services.niks3` (this dir) | niks3 server: S3-backed cache, GC, landing page, read proxy |
| `fmf.services.niks3-auto-upload` | post-build-hook uploader (push every locally built path) |
| `fmf.cache.niks3` | adds the cache as a substituter on clients (URL + public signing key) |
| `fmf.services.garage` | the S3 backend (`backend = "garage"`, the default) |

niks3 is Mic92/niks3. This module is a thin, Vault-fed wrapper around the
upstream NixOS module (`inputs.niks3.nixosModules.niks3`).

## How data moves

niks3 has **no upload proxy**. A push is two conversations:

```
pusher ──(1) niks3 API: "I have these paths"──► niks3        (auth: API token, + mTLS if you front it that way)
pusher ◄─(2) presigned S3 PUT URLs ───────────── niks3
pusher ──(3) PUT the NARs ────────────────────► S3 (Garage)  (auth: the URL's signature)
pusher ──(4) niks3 API: "done" ───────────────► niks3
```

A pull is only talking to niks3. With `settings.readProxy.enable = true` niks3
fetches objects from S3 itself and serves them, so the bucket can stay private
and clients only need niks3's URL.

Consequences worth knowing:

- `s3.publicUrl` is baked into the presigned URLs. It must be a name **pushers
  can reach**. If remote machines push, that is a public S3 hostname, not
  `127.0.0.1:3900`.
- Pushers never need the S3 credentials. Only the niks3 server holds them
  (rendered from Vault by vault-agent). Don't hand them out; they grant the whole
  bucket.

## Who needs which credential

| Action | Credential |
|---|---|
| Push | niks3 **API token** (bearer) — plus a **client cert** if the push endpoint requires mTLS (see below) |
| Pull | nothing on the trusted LAN endpoint; **basic auth** (netrc) on a public endpoint |
| Upload NAR bytes to S3 | the presigned URL niks3 returned (nothing to configure) |
| Garage bucket key | niks3 server only |

Stock Nix cannot present a TLS client certificate to a substituter (it has
`ssl-cert-file` for the CA only). So **pulls cannot use mTLS**; use basic auth
via `netrc-file`, or keep pulls on a trusted network.

niks3 accepts the API token as an alternative to mTLS. If you terminate mTLS in
niks3 itself, the token still works, so mTLS alone does not *enforce* anything.
Enforce it at the reverse proxy instead (next section).

## Server configuration

```nix
fmf.services.niks3 = {
  enable = true;
  # backend = "garage" (default): uses the co-located fmf.services.garage and
  # its "niks3" bucket/key, from Vault.
  httpAddr = "0.0.0.0:5751";               # reachable by the reverse proxy
  cacheUrl = "https://niks3.example.com";
  s3.publicUrl = "https://s3.example.com"; # what pushers will PUT to
  settings.readProxy.enable = true;        # serve reads through niks3
};
```

Vault secrets (KV, default `secret/campground/...`):

- `secret/campground/niks3` — `api_token` (≥ 36 chars), `sign_key`
  (`name:base64`, from `nix key generate-secret`)
- `secret/campground/garage` — Garage RPC secret / admin token
- `secret/campground/garage/buckets/niks3` — `access_key_id`, `secret_access_key`

## Exposing it publicly with enforced client certs

niks3's own mTLS support is for nginx in front (`nginx.mtls`) or native TLS
(`--tls-client-ca`); this module does not wire either (use `settings` if you
need them). Neither *enforces* mTLS because of the token fallback, and native
TLS would also break the local GC job (it calls the server over plain HTTP).

The pattern used in Campground instead is to enforce at the reverse proxy
(Traefik), using **two hostnames**, because Traefik applies client-cert policy
per SNI hostname, not per path:

| Hostname | Routes | Auth |
|---|---|---|
| `niks3.<domain>` | **allowlist** of what niks3's read proxy serves: `/`, `/index.html`, `/nix-cache-info`, `/<hash>.narinfo`, `/nar/*`, `/log/*`, `/realisations/*` | basic auth (pull) |
| `push.niks3.<domain>` | `/api` only | client cert required (`RequireAndVerifyClientCert`) + the API token |
| `s3.<domain>` | Garage S3 API | presigned-URL signatures |

The pull host not routing `/api` is what stops anyone pushing through it with a
stolen token. `/metrics` is served unauthenticated by niks3, so don't route it
publicly. An allowlist (rather than "everything but /api") also keeps
`/health*` and any future niks3 endpoint off the public pull host. The path set
mirrors niks3's `IsValidCachePath` in `server/proxy.go` — re-check it when
bumping the niks3 input.

Keep each hostname **single-purpose**:

- `push.niks3` — only `/api`; no cache reads, no `/metrics`.
- `niks3` — only cache reads; no `/api`.
- `s3` — Garage's S3 API only (never the Garage admin API); the bucket stays
  private, so authorization is purely the SigV4 signature on the presigned URL.

Writes deliberately use **two independent barriers**: the client cert (checked
at the proxy) and the niks3 bearer token (checked by niks3). Leaking one is not
enough to push. Don't try to have the proxy spoof niks3's trusted-proxy mTLS
headers to drop the token: with a proxy on another host that adds a
trusted-header boundary for little gain.

Practical notes:

- `push.niks3.<domain>` is two labels deep: a `*.<domain>` wildcard cert does
  **not** cover it. Give the router its own ACME certificate.
- Put the push and S3 hostnames on **DNS-only** (not Cloudflare-proxied). The
  proxy terminates TLS, so origin mTLS can't work, and large NAR uploads hit
  proxy body limits.
- LAN clients should resolve the public names internally (split DNS) rather than
  hairpinning through the WAN.
- The traefik `fail2ban` plugin used here is a per-IP **request-rate limiter**,
  not a status-code-aware fail2ban: every request counts toward `maxretry`.
  Small values (e.g. `maxretry = 4`) will ban a legitimate uploader. Use loose
  thresholds. Real failure-based banning needs a host fail2ban reading the
  access log.
- Reference implementation: `campground.suites.public-hosting` in the Campground
  repo (routes, TLS option, middleware).

## Vault: getting credentials for a pusher

Run these yourself with your own Vault token.

**Client cert + key** (from the `grpc-farm-pki` PKI; CN must match `ci-*`,
`worker-*` or `lb-*`; role max TTL is 168h):

```bash
umask 077
vault write -format=json grpc-farm-pki/issue/grpc-farm \
  common_name=ci-<name> ttl=72h > /tmp/niks3-cert.json
jq -r .data.certificate /tmp/niks3-cert.json > client.crt
jq -r .data.private_key /tmp/niks3-cert.json > client.key
shred -u /tmp/niks3-cert.json
chmod 600 client.key
```

**API token** (the file must contain only the token, no trailing newline):

```bash
vault read -format=json secret/campground/data/niks3 | jq -j .data.data.api_token > niks3-token
chmod 600 niks3-token
```

Hosts with `fmf.services.nix-grpc-store.client.useFarm = true` already have an
auto-renewed cert at `/var/lib/nix-grpc-store/client.{crt,key}`; prefer that for
long-running pushers over hand-issued 7-day certs.

**Certificate lifetime:** the `grpc-farm` role allows at most **168h**. A
pusher that stores one certificate for months (e.g. a credential held by
another system) needs a different arrangement: a dedicated PKI role/mount with a
longer `max_ttl`, or having that system fetch short-lived certs from Vault. Note
the proxy trusts *any* cert from the CA it is configured with, so a longer-lived
role on the shared farm CA widens who can push; a dedicated mount keeps farm
certs and push certs separate.

## Client configuration

Push (uploader):

```nix
fmf.services.niks3-auto-upload = {
  enable = true;
  serverUrl = "https://push.niks3.example.com";
  # authTokenFile = "/path/to/niks3-token";  # default: from Vault
  settings.mtls = {
    enable = true;
    clientCert = "/var/lib/nix-grpc-store/client.crt";
    clientKey = "/var/lib/nix-grpc-store/client.key";
  };
};
```

Pull from outside the trusted network:

```
# /etc/nix/netrc  (root-owned, 0600)
machine niks3.example.com login <user> password <password>
```

```nix
nix.settings = {
  netrc-file = "/etc/nix/netrc";
  extra-substituters = ["https://niks3.example.com"];
  extra-trusted-public-keys = ["<public half of the niks3 sign_key>"];
};
```

(`fmf.cache.niks3` does this for the trusted-LAN URL and key by default.)

## Operational notes

- **GC only deletes what niks3's database tracks.** It does not list the bucket,
  so S3 objects niks3 has no record of (e.g. after the database was recreated)
  are never garbage collected — and are re-uploaded on the next push — but are
  not deleted. (Checked against niks3's `closure.go`, `objects_model.go`,
  `gc_tasks.go`; not a full audit.)
- **Persist the PostgreSQL data.** `database.createLocally` keeps it in
  `/var/lib/postgresql`; on an ephemeral-root host that is wiped on reboot.
- **Leave `settings.readProxy.redirectTTL` unset if read auth is meant to keep
  the cache private.** With it set, an authenticated NAR request is answered
  with a redirect to a presigned S3 URL, which anyone who obtains it can use
  until it expires (niks3 only redirects NARs, never narinfos). Unset (the
  default) means every read streams through niks3 and clients never talk to S3
  for reads.
- **Reads are integrity-protected by signatures, confidentiality by your auth.**
  If the cache holds nothing sensitive you could leave reads public and rely on
  the signing key; keep read auth if it can contain internal closures.
- **Crystal Forge (TASK-470 niks3 cache support) models write auth as either a
  static token *or* mTLS, never both, and private reads as mTLS only** (per
  `docs/knowledge/caches/niks3-cache.md` on that branch). The layout above
  (mTLS + token for writes, basic auth for reads) therefore isn't expressible
  there yet. That is a Crystal Forge limitation, not a niks3 one.
- **Narinfo probes are noisy.** niks3's default priority (30) is lower than
  cache.nixos.org (40), so Nix queries niks3 first for every path. Expect a very
  high rate of HEAD requests, mostly 404, in Garage's log.

## Running niks3 + Garage in a MicroVM (shared host storage)

Lessons from moving them into a MicroVM that shares the host's existing storage
over virtiofs:

- **Pin the garage uid/gid** in the VM to the host's numeric ids
  (`users.users.garage.uid` / `users.groups.garage.gid`). virtiofs passes
  numeric ids through, so a mismatch gives permission errors on existing data.
- **Guard the data mount.** If the data dir is its own ZFS dataset (`nofail`),
  give `microvm@<vm>` and `microvm-virtiofsd@<vm>` `RequiresMountsFor` for it,
  so the VM never starts on the empty directory underneath.
- **`garage-marker`.** Garage records a marker for each data dir in its
  `data_layout` and refuses to start if the file is missing from the data dir
  ("Could not find expected marker file"). A long-running Garage never re-checks,
  so a marker lost earlier only shows up on the next restart. If you are
  certain the right dataset is mounted, recreate it from the value stored in
  `data_layout` (exact bytes, **no trailing newline**):
  `grep -aoE '[0-9a-f]{64}' <meta>/data_layout` (expect exactly one match), then
  `printf '%s' <value> > <data_dir>/garage-marker`, owned by the garage user.
- **LMDB on virtiofs works** for Garage metadata (observed with Garage 2.4.1;
  it opened `db.lmdb` and ran), though that is a single observation, not a
  guarantee.
- **Back up first.** Stop Garage, copy the metadata dir, and snapshot the data
  dataset before the first start in the new place.
