{ lib, inputs }:

let
  inherit (inputs) deploy-rs;
in
rec {
  mkDeploy = { self, overrides ? { } }:
    let
      hosts = self.nixosConfigurations or { };
      names = builtins.attrNames hosts;
      nodes = lib.foldl
        (result: name:
          let
            host = hosts.${name};
            user = host.config.campground.user.name or null;
            inherit (host.pkgs) system;
          in
          result // {
            ${name} = (overrides.${name} or { }) // {
              hostname = overrides.${name}.hostname or "${name}";
              profiles = (overrides.${name}.profiles or { }) // {
                system = (overrides.${name}.profiles.system or { }) // {
                  path = deploy-rs.lib.${system}.activate.nixos host;
                } // lib.optionalAttrs (user != null) {
                  user = "root";
                  # made root not mcamp cause it wont work.. seems to be the same issue here https://github.com/serokell/deploy-rs/issues/174
                  sshUser = "root";
                } // lib.optionalAttrs
                  (host.config.campground.security.doas.enable or false)
                  {
                    sudo = "doas -u";
                  };
              };
            };
          })
        { }
        names;
    in
    { inherit nodes; };
}
