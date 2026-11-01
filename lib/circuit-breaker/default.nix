{lib, ...}: let
  inventory = import ./inventory.nix {inherit lib;};
in {
  # lib.fmf.circuitBreaker.mkInventory { nixosConfigurations; flake; options; }
  circuitBreaker =
    inventory
    // {
      net = import ./net.nix {inherit lib;};
      catalog = import ./catalog.nix;

      # Render an inventory attrset as a JSON store file.
      mkInventoryFile = pkgs: inv:
        pkgs.writeText "circuit-breaker-inventory.json" (builtins.toJSON inv);
    };
}
