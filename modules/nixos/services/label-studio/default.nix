{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  labelStudioSocket = "/run/label-studio.sock";
  cfg = config.campground.services.label-studio;
in
{
  options.campground.services.label-studio = with types; {
    enable = mkBoolOpt false "Enable label-studio;";
    port = mkOpt int 8080 "Port to listen on";
    dbURI = mkOpt str "postgresql+psycopg2://labelstudio:@/labelstudio?host=/var/run/postgresql" "DB URI";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      label_studio
    ];
    users.users.labelstudio = {
      isNormalUser = false;
      isSystemUser = true;
      description = "Label Studio System User";
      group = "labelstudio";
      extraGroups = [ "labelstudio" ]; # Optional if you want the user to be in additional groups
      home = "/var/lib/label-studio";
    };
    users.groups.labelstudio = {};

    systemd.tmpfiles.rules = [
      "d /var/lib/label-studio 0755 labelstudio labelstudio -"
    ];


    systemd.services.label-studio = {
      description = "Label Studio";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        DJANGO_DB="postgresql";
        POSTGRE_NAME="labelstudio";
        POSTGRE_USER="labelstudio";
        POSTGRE_PORT="5432";
        POSTGRE_HOST="/var/run/postgresql";

      };
      script = ''
      ${pkgs.label_studio}/bin/label-studio start --database "${cfg.dbURI}" --host 127.0.0.1 --port 5903
      '';
      serviceConfig = {
        User = "labelstudio";
      };
    };

    campground.services.postgresql = {
      enable = true;
      # TODO: configure authentication in a way that its set here and doesn't break other places
      # authentication = ''
      #   local all root trust
      #   local all postgres peer
      #   local vaultwarden vaultwarden trust
      #   local mattermost mattermost trust
      #   host  all  all  0.0.0.0/0  reject
      #   host  all  all  ::0/0  reject
      # '';
      databases = [ 
        { 
          name = "labelstudio"; 
          user = "labelstudio"; 
        } 
      ];
    };
    services.nginx = {
      enable = true;
      virtualHosts = {
          "label-studio.lan" = {
          listen = [ { addr = "0.0.0.0"; port = cfg.port; } ];  # Specify the port here
          http2 = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:5903";
            proxyWebsockets = true;
          };
        };
      };
    };

  };
}
