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
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_13;
      initialScript = pkgs.writeText "postgresql-init.sql" ''
        CREATE DATABASE mydatabase;
        CREATE USER postgres WITH PASSWORD 'postgrespassword';
        GRANT ALL PRIVILEGES ON DATABASE mydatabase TO postgres;
      '';
    };
  };
}
