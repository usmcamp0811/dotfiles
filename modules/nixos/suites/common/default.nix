{ options
, config
, lib
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.suites.common;
in
{
  options.campground.suites.common = with types; {
    enable = mkBoolOpt false "Whether or not to enable common configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ ];

    campground = {
      nix = {
        enable = true;
        extra-substituters = {
          # Core NixOS cache (you might already have this as default)
          "https://cache.nixos.org" = {
            key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
          };

          # Hyprland cache (for your Wayland setup)
          "https://hyprland.cachix.org" = {
            key = "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=";
          };

          # Nix community cache
          "https://nix-community.cachix.org" = {
            key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
          };

          # NUR cache - KEY for Firefox addons!
          "https://nur.cachix.org" = {
            key = "nur.cachix.org-1:WG6ry5dehFKjDzEkgxcGdQQGt1IRbJLtL0F6bJwfnr8=";
          };
        };
      };
      cache = {
        public = enabled;
        campground = enabled;
      };

      cli-apps = { flake = enabled; };

      tools = {
        git = enabled;
        misc = enabled;
        nix-output-monitor = enabled;
        comma = enabled;
      };

      hardware = {
        audio = enabled;
        networking = enabled;
      };

      services = {
        crystal-forge = {
          enable = true;
          client = {
            enable = true;
            server_host = "reckless";
            server_port = 3444;
          };
        };
        openssh = {
          enable = true;
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGw+o+9F4kz+dYyI2I4WudgKjyFOK+L0QW4LhxkG4sMt gitlab-runner@aicampground.com"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdMWMFyi7Lvjm78KOX3tKZ5bkEZ7bHA56ZKKtTb9wIo mcamp@aicampground.com"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAclfREva2i4LsnBQPY3ZSsZzeuS5DGn11u0abBR8cFv mcamp@butler"
          ];
        };
      };

      security = { keyring = enabled; };

      system = {
        boot = enabled;
        fonts = enabled;
        locale = enabled;
        time = enabled;
        xkb = enabled;
      };
    };
  };
}
