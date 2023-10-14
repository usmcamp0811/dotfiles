{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.services.oci-container-login;
in
{
  options.campground.services.oci-container-login = with types; {
    enable = mkBoolOpt false "Whether or not to enable oci-container-login.";
    username = mkOpt str "usmcamp0811" "User name";
    registery = mkOpt str "docker.io" "Registry to login to";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/container-registeries" "The vault path to the kv with container registery passwords";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.my-podman-login = {
      description = "Podman Login";
      wantedBy = [ "multi-user.target" ];
      before = [ "your-container-service.service" ]; # Replace with actual service name
      script = ''
        # Your logic here. For example:
        podman login ${cfg.registery} --username ${cfg.username} --password-stdin < /home/mcamp/dockerhub
      '';
    };

    # campground.services.vault-agent.services.copyCAcert = {
    #   settings = {
    #     vault.address = cfg.vault-address;
    #     auto_auth = {
    #       method = [{
    #         type = "approle";
    #         config = {
    #           role_id_file_path = cfg.role-id;
    #           secret_id_file_path = cfg.secret-id;
    #           remove_secret_id_file_after_reading = false;
    #         };
    #       }];
    #     };
    #   };
    #   secrets = {
    #     file = {
    #       files = {
    #         "ca.crt" = {
    #           text = ''
    #             {{ with secret "${cfg.vault-pki-path}" "common_name=${cfg.common-name}" }}
    #             {{ .Data.issuing_ca }}
    #             {{ end }}
    #           '';
    #           permissions = "0600";
    #           change-action = "restart";
    #         };
    #       };
    #     };
    #   };
    # };
  };

}

