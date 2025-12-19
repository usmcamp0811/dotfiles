{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.example_postgresql;
in {
  options.fmf.services.example_postgresql = with types; {
    enable =
      mkBoolOpt false
      "Create an example DB to be used with the Vault DB Readme";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [5432]; # Open PostgreSQL port
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_13;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        # Allow only local connections for the root user
        local all postgres peer
        # Require password for Vault-generated users over the network
        host  all  all  10.8.0.1/24  md5
        # Deny other remote connections
        host  all  all  0.0.0.0/0  reject
        host  all  all  ::0/0  reject
      '';
      initialScript = pkgs.writeText "postgresql-init.sql" ''
        CREATE DATABASE mydatabase;
        CREATE USER postgres WITH PASSWORD 'postgrespassword';
        GRANT ALL PRIVILEGES ON DATABASE mydatabase TO postgres;
      '';
    };
  };
}
