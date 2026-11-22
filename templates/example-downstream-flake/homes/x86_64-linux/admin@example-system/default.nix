# Second user on example-system. Snowfall-lib creates one user per `<user>@<host>` folder whose host
# matches, so this folder alone gives example-system an `admin` account (users.users.admin, in wheel)
# and a Home Manager configuration for it. Settings only the system can set (uid, shell, SSH keys) are
# in systems/x86_64-linux/example-system/default.nix. See fmf docs/MULTI-USER-HOSTS.md.
{lib, ...}:
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = "admin";
      fullName = "Example Admin";
      email = "admin@example.com";
      uid = 1001;
    };

    tools = {git = enabled;};
  };

  home.stateVersion = "23.05";
}
