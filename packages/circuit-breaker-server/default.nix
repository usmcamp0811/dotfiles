# Circuit Breaker server (backend + web UI), built natively - no container image.
#
#   result/bin/cb-python    Python 3.12 with the backend and every pinned dependency
#   result/share/frontend   the built web UI (served by the backend)
#   result/share/backend    alembic.ini + migrations
#
# Provenance:
#   * source: the upstream release commit pinned in lib/circuit-breaker/upstream.nix
#   * Python dependencies: exactly the versions and file hashes in upstream's poetry.lock,
#     fetched once as a hash-pinned wheelhouse (wheelhouse.nix) and installed offline;
#     native extensions are patched for NixOS with autoPatchelf
#   * web UI: built from package-lock.json (frontend.nix)
# Regenerate requirements.lock.txt with gen-lock.py when bumping the release.
{
  lib,
  stdenv,
  fetchFromGitHub,
  callPackage,
  python312,
  autoPatchelfHook,
  makeWrapper,
  zlib,
  ...
}: let
  up = import ../../lib/circuit-breaker/upstream.nix;
  src = fetchFromGitHub {inherit (up) owner repo rev hash;};
  wheelhouse = callPackage ./wheelhouse.nix {};
  frontend = callPackage ./frontend.nix {
    inherit src;
    inherit (up) version;
  };
  python = python312;
  sitePackages = "lib/${python.libPrefix}/site-packages";
in
  assert lib.assertMsg (stdenv.hostPlatform.system == "x86_64-linux") "circuit-breaker-server: the wheelhouse is locked for x86_64-linux";
    stdenv.mkDerivation {
      pname = "circuit-breaker-server";
      inherit (up) version;
      inherit src;

      # Local fixes on top of the pinned upstream release (each is explained in its file).
      #  - oidc-id-token-audience: upstream verifies the OIDC id_token without an expected
      #    audience, which PyJWT rejects for every real provider (InvalidAudienceError), so
      #    no OIDC login (Authentik, Keycloak, ...) could ever succeed.
      #  - oidc-csrf-cookie: the OAuth/OIDC redirects set the session cookie but not the CSRF
      #    cookie, and the CSRF middleware refuses every write without one, so anyone signed
      #    in through an identity provider could read but not change anything (HTTP 403,
      #    "CSRF token missing", e.g. the scan acknowledgment and the settings page).
      patches = [
        ./patches/oidc-id-token-audience.patch
        ./patches/oidc-csrf-cookie.patch
      ];

      nativeBuildInputs = [python python.pkgs.pip autoPatchelfHook makeWrapper];
      buildInputs = [stdenv.cc.cc.lib zlib];

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        # 1. dependencies: offline, hash-verified, no resolver
        python -m pip install \
          --no-index --find-links ${wheelhouse} \
          --no-deps --require-hashes --no-compile --disable-pip-version-check \
          --prefix $out -r ${./requirements.lock.txt}
        # python-nmap is a pure-Python package PyPI only ships as an sdist; upstream vendors a wheel
        echo "$(cut -d' ' -f1 packaging/wheels/*.whl.sha256)  $(echo packaging/wheels/*.whl)" | sha256sum -c -
        python -m pip install --no-index --no-deps --no-compile --disable-pip-version-check \
          --prefix $out packaging/wheels/*.whl

        # 2. the application itself
        cp -r apps/backend/src/app $out/${sitePackages}/app
        find $out/${sitePackages}/app -name __pycache__ -prune -exec rm -rf {} +

        # 3. data the app reads at run time
        mkdir -p $out/share/backend
        cp apps/backend/alembic.ini $out/share/backend/
        cp -r apps/backend/migrations $out/share/backend/migrations
        cp VERSION $out/share/VERSION
        ln -s ${frontend} $out/share/frontend

        # 4. entry point: Python with the application on the path, bytecode off (read-only store)
        mkdir -p $out/bin
        makeWrapper ${python}/bin/python3 $out/bin/cb-python \
          --set PYTHONPATH $out/${sitePackages} \
          --set PYTHONNOUSERSITE 1 \
          --set PYTHONDONTWRITEBYTECODE 1 \
          --set PYTHONUNBUFFERED 1 \
          --set-default CB_SHARE_DIR $out/share \
          --set-default STATIC_DIR $out/share/frontend \
          --set-default CB_ALEMBIC_INI $out/share/backend/alembic.ini \
          --set-default ALEMBIC_CONFIG $out/share/backend/alembic.ini
        # pip's console scripts point at the build interpreter; nothing uses them
        find $out/bin -type f ! -name cb-python -delete

        runHook postInstall
      '';

      doInstallCheck = true;
      installCheckPhase = ''
        runHook preInstallCheck
        # every pinned module imports (this is what catches a missing/unpatched native library)
        export CB_DB_URL=postgresql://check:check@127.0.0.1:1/check CB_JWT_SECRET=$(printf "x%.0s" {1..40})
        $out/bin/cb-python - <<'PY'
        import importlib, sys
        for m in ["fastapi", "uvicorn", "sqlalchemy", "asyncpg", "psycopg2", "cryptography", "pydantic_core",
                  "argon2", "bcrypt", "nats", "redis", "alembic", "nmap", "PIL", "uvloop", "httptools", "scapy", "pysnmp", "docker",
                  "watchfiles", "websockets", "yaml", "zeroconf", "greenlet", "psutil", "hiredis", "app.main"]:
            importlib.import_module(m)
        from app.core.config import resolve_app_version
        v = resolve_app_version()
        assert v == "${up.version}", v
        print("imports ok, version", v)
        PY

        # OIDC sign-in: the id_token audience must be the configured client_id (see the patch)
        $out/bin/cb-python - <<'PY'
        import json, time
        import jwt
        from cryptography.hazmat.primitives.asymmetric import rsa
        from fastapi import HTTPException
        from jwt.algorithms import RSAAlgorithm
        from app.api.auth_oauth import _verify_id_token_nonce as verify

        def rejected(fn):
            try:
                fn()
            except HTTPException as e:
                return e.status_code == 400
            return False

        claims = {"aud": "client-1", "nonce": "n1", "exp": int(time.time()) + 300, "iss": "https://idp.example"}
        secret = "s" * 40
        hs = jwt.encode(claims, secret, algorithm="HS256")
        verify(hs, {}, "n1", client_secret=secret, audience="client-1")
        assert rejected(lambda: verify(hs, {}, "n1", client_secret=secret, audience="someone-else"))
        assert rejected(lambda: verify(hs, {}, "wrong-nonce", client_secret=secret, audience="client-1"))

        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        jwk = json.loads(RSAAlgorithm.to_jwk(key.public_key())); jwk["kid"] = "k1"
        rs = jwt.encode({**claims, "aud": ["other", "client-1"]}, key, algorithm="RS256", headers={"kid": "k1"})
        verify(rs, {"keys": [jwk]}, "n1", audience="client-1")
        assert rejected(lambda: verify(rs, {"keys": [jwk]}, "n1", audience="someone-else"))
        print("oidc audience checks ok")
        PY

        # OIDC sign-in must leave the browser able to write: both cookies, same attributes as password login
        $out/bin/cb-python - <<'PY'
        import inspect
        from fastapi.responses import RedirectResponse
        from starlette.requests import Request
        from app.core import auth_cookie
        from app.api import auth_oauth

        def req(scheme):
            return Request({"type": "http", "method": "GET", "path": "/", "query_string": b"", "scheme": scheme,
                            "server": ("topology.example", 443), "client": ("10.0.0.9", 1234),
                            "headers": [(b"host", b"topology.example")]})

        for scheme, secure in (("https", True), ("http", False)):
            r = RedirectResponse("/")
            auth_cookie.set_auth_cookie_on_response(req(scheme), r, "tok", 24)
            auth_cookie.set_csrf_cookie_on_response(req(scheme), r, 24)
            cookies = {c.split("=", 1)[0]: c for c in r.headers.getlist("set-cookie")}
            assert set(cookies) == {"cb_session", "cb_csrf"}, cookies
            csrf, sess = cookies["cb_csrf"], cookies["cb_session"]
            assert "httponly" not in csrf.lower(), csrf          # JS must be able to read it
            assert "httponly" in sess.lower(), sess
            assert ("secure" in csrf.lower()) == secure and "samesite=strict" in csrf.lower(), csrf
            assert len(csrf.split("=", 1)[1].split(";")[0]) == 64, csrf
        for fn in (auth_oauth._issue_jwt_and_redirect, auth_oauth._bootstrap_redirect_or_none):
            assert "set_csrf_cookie_on_response(" in inspect.getsource(fn), fn.__name__
        print("oidc csrf cookie checks ok")
        PY
        runHook postInstallCheck
      '';

      passthru = {inherit wheelhouse frontend python;};

      meta = {
        description = "Circuit Breaker homelab topology server (native build of upstream ${up.version})";
        homepage = "https://github.com/BlkLeg/CircuitBreaker";
        license = lib.licenses.mit;
        platforms = ["x86_64-linux"];
        mainProgram = "cb-python";
      };
    }
