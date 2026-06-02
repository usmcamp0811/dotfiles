# This overlay must be applied early via flake.nix's overlays list
# to be available during package evaluation
{ unstable, ... }:
final: prev: let
  system = prev.stdenv.hostPlatform.system;
in {
  # Import unstable with explicit config to allow unfree packages (including CUDA)
  nix-unstable = import unstable {
    inherit system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      # Allow all unfree packages without restriction
      allowUnfreePredicate = _: true;
    };
  };
}
