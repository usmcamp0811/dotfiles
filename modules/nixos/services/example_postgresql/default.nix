{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.example_postgresql;
in
{
  options.campground.services.example_postgresql = with types; {
    enable = mkBoolOpt false "Create an example DB to be used with the Vault DB Readme";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 5432 ];  # Open PostgreSQL port

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_13;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        host  all  all  10.8.0.1/24  trust
        local postgres postgres trust
      '';
      initialScript = pkgs.writeText "postgresql-init.sql" ''
        CREATE DATABASE mydatabase;
        CREATE USER postgres WITH PASSWORD 'postgrespassword';
        GRANT ALL PRIVILEGES ON DATABASE mydatabase TO postgres;
      '';
    };
  };
}
