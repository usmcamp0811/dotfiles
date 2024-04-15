{
  lib,
  inputs,
}: let
  inherit (inputs) deploy-rs;
in rec {
  ## Create deployment configuration for use with deploy-rs.
  ##
  ## ```nix
  ## mkDeploy {
  ##   inherit self;
  ##   overrides = {
  ##     my-host.system.sudo = "doas -u";
  ##   };
  ## }
  ## ```
  ##
  #@ { self: Flake, overrides: Attrs ? {} } -> Attrs
  mkDeploy = {
    self,
    overrides ? {},
  }: let
    hosts = self.nixosConfigurations or {};
    names = builtins.attrNames hosts;
    nodes = lib.foldl (result: name: let
      host = hosts.${name};
      inherit (host.pkgs) system;
      # Condition to check if the system type is x86_64-linux
      isActive = system == "x86_64-linux";
    in
      if !isActive then result
      else
        result // {
          ${name} =
            (overrides.${name} or {})
            // {
              hostname = overrides.${name}.hostname or "${name}";
              profiles =
                (overrides.${name}.profiles or {})
                // {
                  system =
                    (overrides.${name}.profiles.system or {})
                    // {
                      path = deploy-rs.lib.${system}.activate.nixos host;
                    }
                    // lib.optionalAttrs (host.config.users.users.${host.config.campground.user.name or "root"}.isNormalUser or false) {
                      user = "root";
                      sshUser = "root";
                    }
                    // lib.optionalAttrs
                    (host.config.campground.security.doas.enable or false) {
                      sudo = "doas -u";
                    };
                };
            };
        }) {}
    names;
  in {inherit nodes;};
}
