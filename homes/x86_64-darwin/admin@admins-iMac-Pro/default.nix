{ inputs, lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib;
with lib.campground; {
  campground = {
    user = {
      enable = true;
      name = "admin";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
    };

    cli = {
      zsh = enabled;
      bash = enabled;
      env = enabled;
      home-manager = enabled;
      ranger = enabled;
      neovim = enabled;
      misc = enabled;
    };
    services = {
      openssh = {
        enable = true;
        authorizedKeys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCz1jfoM5vFTtLxbHhhFQbKbMxy589qWE3vnWAYJJ9vUSh8k2uqLrwT/5z9dd5/+cvCsz3EcRJR7zlE1hGkyYfGgkEUhEvC2g5uVHtNlEAyAycHqJ/EmjdUdKITSnF92GEA4EpyOZWjlxPnOVsaqNqw0E3hekDJN6e88jjR3wszOf4bVmpDfg64tM6GHfArI7fbkiR4NhgZm5u90yVr+7orrUKQddkmqVxEovqU0iJmXRRwTRLKYWN5B1kqEGsy2z82DLO6GHCvLEb0kXt7SX00Y+1yIoToMpJLRCaHcdcGsNszdO/X8GYHK0IFN43+1M47FF0Dd0nBx7T98tgute7cg7yl5JM0ocJRUILbPXXan6iY6YMz7aJrsspvcXzh8WiY1zJkVWuWCdbYM9DtlXrT5AbWx3h/RZntxadd/mGKKgsS5x8N/aBLLgwZExjumBzNo9XoCpJ+C2/TjEFLpk/6vS+jM1klla/okiyr7OZ9DdRddjgFA8yNcWfsO8blE/c= mcamp@ATA-NUC"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAclfREva2i4LsnBQPY3ZSsZzeuS5DGn11u0abBR8cFv mcamp@butler"
        ];

        extraConfigs = ''
          Host github.com-usmcamp0811
            HostName github.com
            User git
            IdentityFile ~/.ssh/id_ed25519
            IdentitiesOnly yes

          Host github.com-mcamp-ata
            HostName github.com
            User git
            IdentityFile ~/.ssh/id_rsa.ata
            IdentitiesOnly yes
        '';
      };
      syncthing = enabled;
    };

    apps = {
      firefox = enabled;
      brave = enabled;
      libreoffice = enabled;
      alacritty = enabled;
      mpv = enabled;
      zoom = enabled;
      qutebrowser = enabled;
      ckb-next = enabled;
      mattermost-desktop = enabled;
      slack = enabled;
    };
    tools = {
      git = enabled;
      vault = enabled;
      direnv = enabled;
      virtmanager = enabled; # don't forget to add to libvirtd group
      julia = enabled;
      # jupyter = enabled;
      # python = enabled;
      emoji-picker = enabled;
      # dvc = enabled;
    };
  };

  home.stateVersion = "23.05";
}
