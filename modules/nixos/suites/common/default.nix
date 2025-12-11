{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.suites.common;
in {
  options.campground.suites.common = with types; {
    enable = mkBoolOpt false "Whether or not to enable common configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [];

    crystal-forge.stig-presets.off.enable = true;
    campground = {
      cli = {zsh.root = enabled;};
      nix = {
        enable = true;
        extra-substituters = {
          # Core NixOS cache
          "https://cache.nixos.org" = {
            key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
          };

          # Nix community cache
          "https://nix-community.cachix.org" = {
            key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
          };

          # CUDA maintainers cache
          "https://cuda-maintainers.cachix.org" = {
            key = "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=";
          };

          # Nixpkgs Wayland cache
          "https://nixpkgs-wayland.cachix.org" = {
            key = "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA=";
          };

          # Hyprland cache
          "https://hyprland.cachix.org" = {
            key = "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=";
          };

          # Nixpkgs Python cache
          "https://nixpkgs-python.cachix.org" = {
            key = "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=";
          };

          # Anyrun cache (from your second config)
          "https://anyrun.cachix.org" = {
            key = "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s=";
          };

          # Yazi cache (from your second config)
          "https://yazi.cachix.org" = {
            key = "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k=";
          };

          # Numtide cache
          "https://numtide.cachix.org" = {
            key = "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=";
          };
        };
      };

      cache = {
        public = enabled;
        campground = enabled;
      };

      cli-apps = {flake = enabled;};

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
          server = {
            port = 3444;
          };
          deployment = {
            cache_url = "https://attic.aicampground.com/campground";
            cache_public_key = "campground:rBZu4QGW0Rkj/u13zd/qNcdrDc+XBReGJbPQx/nf3R4=";
            deployment_poll_interval = "5";
            fallback_to_local_build = false;
            # require_sigs = false;
          };
          client = {
            enable = true;
            server_host = "crystal-forge.aicampground.com";
            server_port = 443;
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

      security = {keyring = enabled;};

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
