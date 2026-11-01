# Building the reconciler runs its pytest suite (a fake of the real 0.4.6 API,
# generated from the upstream OpenAPI document) in the package's checkPhase.
{pkgs, ...}: pkgs.fmf.circuit-breaker-sync
