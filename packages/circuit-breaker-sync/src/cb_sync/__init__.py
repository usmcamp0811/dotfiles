"""Idempotent reconciler: Nix flake inventory -> Circuit Breaker.

Standard library only, on purpose: this runs as a long-lived root-adjacent
service on a NixOS host and every extra dependency is extra attack surface.
"""

__version__ = "0.1.0"

#: The Circuit Breaker release this adapter was verified against. The /api/v1
#: surface is not a stable public API (upstream says so), so all API-specific
#: behaviour lives in ``adapter.py`` / ``client.py`` and is checked against the
#: server's own OpenAPI document at runtime.
TESTED_CB_VERSION = "0.4.6"
