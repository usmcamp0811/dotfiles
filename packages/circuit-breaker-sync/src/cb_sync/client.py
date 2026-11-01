"""Thin HTTP client for the Circuit Breaker ``/api/v1`` API.

Only transport concerns live here: authentication header, TLS policy, timeouts,
bounded retries with backoff, and error classification. *What* to call is the
business of ``adapter.py``/``reconcile.py``.

Authentication is a bearer API token / service-account JWT. The deprecated
``CB_API_TOKEN`` grant is not supported and never used.
"""

from __future__ import annotations

import hashlib
import http.client
import json
import re
import socket
import ssl
import time
import urllib.parse
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

USER_AGENT = "circuit-breaker-sync/0.1 (+nix)"
MAX_RETRY_AFTER = 60.0


class ApiError(Exception):
    def __init__(self, message: str, *, status: int | None = None, body: Any = None) -> None:
        super().__init__(message)
        self.status = status
        self.body = body


class AuthError(ApiError):
    """401/403: the credential is missing, expired, revoked, or too weak."""


class NotFound(ApiError):
    pass


class Conflict(ApiError):
    pass


class TransientError(ApiError):
    """Retries exhausted on a retryable failure (connection, timeout, 429, 5xx)."""


class AmbiguousWrite(TransientError):
    """A non-idempotent request may or may not have been applied.

    Callers must re-read state before retrying (see ``Reconciler._create``).
    """


@dataclass(frozen=True)
class TlsConfig:
    """How to verify the server certificate.

    * ``system``  - normal verification against the system trust store.
    * ``ca-file`` - verify against a specific CA bundle.
    * ``pin``     - accept exactly one certificate, identified by the SHA-256 of
      its DER encoding. This is what we use against the container's own
      self-signed certificate: no CA chain, no hostname check, but an exact
      match (the same idea as the agent's ``tls_pin``).
    * ``insecure``- no verification. Refused unless explicitly requested.
    """

    mode: str = "system"
    ca_file: str | None = None
    pin_sha256: str | None = None

    @staticmethod
    def pin_from_pem_file(path: str | Path) -> "TlsConfig":
        pem = Path(path).read_text(encoding="ascii")
        m = re.search(r"-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----", pem, re.S)
        if not m:
            raise ValueError(f"no certificate found in {path}")
        der = ssl.PEM_cert_to_DER_cert(m.group(0))
        return TlsConfig(mode="pin", pin_sha256=hashlib.sha256(der).hexdigest())


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    def __init__(self, *args: Any, pin_sha256: str, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self._pin = pin_sha256.lower().removeprefix("sha256:")

    def connect(self) -> None:  # noqa: D401 - stdlib override
        super().connect()
        der = self.sock.getpeercert(binary_form=True)  # type: ignore[union-attr]
        got = hashlib.sha256(der or b"").hexdigest()
        if got != self._pin:
            self.close()
            raise ssl.SSLError(f"server certificate pin mismatch (got sha256:{got})")


def _ssl_context(tls: TlsConfig) -> ssl.SSLContext:
    if tls.mode == "system":
        return ssl.create_default_context()
    if tls.mode == "ca-file":
        return ssl.create_default_context(cafile=tls.ca_file)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


class Client:
    """Minimal JSON-over-HTTP client with retry/backoff."""

    def __init__(
        self,
        base_url: str,
        token: str | None,
        *,
        tls: TlsConfig | None = None,
        timeout: float = 15.0,
        retries: int = 4,
        backoff: float = 0.5,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        parsed = urllib.parse.urlsplit(base_url)
        if parsed.scheme not in ("http", "https") or not parsed.hostname:
            raise ValueError(f"invalid base URL: {base_url!r}")
        self.scheme = parsed.scheme
        self.host = parsed.hostname
        self.port = parsed.port or (443 if parsed.scheme == "https" else 80)
        self.prefix = parsed.path.rstrip("/")
        self.token = token
        self.tls = tls or TlsConfig()
        self.timeout = timeout
        self.retries = retries
        self.backoff = backoff
        self.sleep = sleep
        self.requests = 0

    # -- transport ---------------------------------------------------------
    def _connection(self) -> http.client.HTTPConnection:
        if self.scheme == "http":
            return http.client.HTTPConnection(self.host, self.port, timeout=self.timeout)
        if self.tls.mode == "pin":
            if not self.tls.pin_sha256:
                raise ValueError("TLS pin mode requires a pin")
            return _PinnedHTTPSConnection(
                self.host,
                self.port,
                timeout=self.timeout,
                context=_ssl_context(self.tls),
                pin_sha256=self.tls.pin_sha256,
            )
        return http.client.HTTPSConnection(
            self.host, self.port, timeout=self.timeout, context=_ssl_context(self.tls)
        )

    def request(
        self,
        method: str,
        path: str,
        body: Any = None,
        *,
        params: dict[str, Any] | None = None,
        idempotent: bool | None = None,
        ok: tuple[int, ...] = (200, 201, 202, 204),
    ) -> Any:
        """Perform a request and return decoded JSON (or ``None`` for empty bodies).

        ``idempotent`` defaults to True for everything except POST. A
        non-idempotent request is retried only on responses that prove it was not
        applied (429, 503); any ambiguous transport failure raises
        :class:`AmbiguousWrite`.
        """
        if idempotent is None:
            idempotent = method.upper() != "POST"
        url = f"{self.prefix}{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        payload = None if body is None else json.dumps(body).encode()
        headers = {
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        }
        if payload is not None:
            headers["Content-Type"] = "application/json"
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        last: Exception | None = None
        for attempt in range(self.retries + 1):
            if attempt:
                self.sleep(min(self.backoff * (2 ** (attempt - 1)), MAX_RETRY_AFTER))
            conn = None
            try:
                conn = self._connection()
                self.requests += 1
                conn.request(method, url, body=payload, headers=headers)
                resp = conn.getresponse()
                raw = resp.read()
                status = resp.status
                retry_after = resp.getheader("Retry-After")
            except (OSError, http.client.HTTPException, ssl.SSLError, socket.timeout) as exc:
                last = exc
                if isinstance(exc, ssl.SSLError) and "pin mismatch" in str(exc):
                    raise ApiError(f"TLS verification failed: {exc}") from exc
                # Refused connections prove nothing was sent; everything else is ambiguous.
                refused = isinstance(exc, ConnectionRefusedError)
                if not idempotent and not refused:
                    raise AmbiguousWrite(f"{method} {path}: {exc}") from exc
                continue
            finally:
                if conn is not None:
                    conn.close()

            data: Any = None
            if raw:
                try:
                    data = json.loads(raw)
                except ValueError:
                    data = raw.decode("utf-8", "replace")[:500]

            if status in ok:
                return data
            if status in (401, 403):
                raise AuthError(f"{method} {path}: HTTP {status} {_detail(data)}", status=status, body=data)
            if status == 404:
                raise NotFound(f"{method} {path}: not found", status=status, body=data)
            if status == 409:
                raise Conflict(f"{method} {path}: conflict {_detail(data)}", status=status, body=data)
            if status in (429, 503, 502, 504):
                last = ApiError(f"{method} {path}: HTTP {status} {_detail(data)}", status=status, body=data)
                # 429/503 prove the write was not applied. 502/504 do not.
                if not idempotent and status in (502, 504):
                    raise AmbiguousWrite(str(last), status=status, body=data)
                if attempt < self.retries and retry_after:
                    try:
                        self.sleep(min(float(retry_after), MAX_RETRY_AFTER))
                    except ValueError:
                        pass
                continue
            raise ApiError(f"{method} {path}: HTTP {status} {_detail(data)}", status=status, body=data)

        raise TransientError(f"{method} {path}: gave up after {self.retries + 1} attempts: {last}")

    # -- conveniences -------------------------------------------------------
    def get(self, path: str, **params: Any) -> Any:
        return self.request("GET", path, params=params or None)

    def post(self, path: str, body: Any = None) -> Any:
        return self.request("POST", path, body)

    def patch(self, path: str, body: Any) -> Any:
        return self.request("PATCH", path, body)

    def delete(self, path: str) -> Any:
        return self.request("DELETE", path)


def _detail(data: Any) -> str:
    if isinstance(data, dict):
        d = data.get("detail", data.get("error_code", ""))
        return str(d)[:300]
    return str(data)[:300] if data else ""
