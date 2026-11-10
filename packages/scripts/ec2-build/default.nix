{
  pkgs,
  lib,
  inputs,
  ...
}:
# ec2-build: run a Nix command with a throwaway aarch64 EC2 instance as its remote builder.
#
#   nix run .#ec2-build -- --env-file ~/.config/ec2-build.env -- nix build .#<aarch64 thing>
#
# See README.md. The infrastructure is terraform.nix (terranix), applied with OpenTofu.
let
  # Generated once at build time; per-run values are OpenTofu variables.
  tfConfig = inputs.terranix.lib.terranixConfiguration {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [./terraform.nix];
  };

  # The AWS provider is bundled, so `tofu init` downloads nothing.
  tofu = pkgs.opentofu.withPlugins (p: [p.hashicorp_aws]);
in
  pkgs.writeShellApplication {
    name = "ec2-build";
    # nix itself is deliberately not here: the command runs with the caller's nix.
    runtimeInputs = [tofu] ++ (with pkgs; [openssh jq curl coreutils findutils gawk]);
    text = builtins.replaceStrings ["@TF_CONFIG@"] ["${tfConfig}"] (builtins.readFile ./ec2-build.sh);
    passthru = {inherit tfConfig tofu;};
    meta = with lib; {
      description = "Run a Nix command with a throwaway aarch64 EC2 instance as its remote builder, then destroy it";
      license = licenses.mit;
      platforms = platforms.linux;
      mainProgram = "ec2-build";
    };
  }
