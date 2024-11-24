{ pkgs, lib, ... }:
let
  name = "ado-pipeline-agent";
  version = "4.248.0";
  src = pkgs.fetchurl {
    url =
      # "https://vstsagentpackage.azureedge.net/agent/4.248.0/vsts-agent-linux-x64-4.248.0.tar.gz";
      "https://vstsagentpackage.azureedge.net/agent/${version}/vsts-agent-linux-x64-${version}.tar.gz";
    sha256 = "sha256-o6KCgV/4II6ykdfncSXOtr388n3Gaht9pen9EbCVL78=";
  };

  # we use an FHS here mostly because I don't know what .Net stuff needs and this is simpler for now
  # TODO: remove FHS if not needed
  fhsEnv = pkgs.buildFHSUserEnv {
    inherit name;
    targetPkgs = pkgs:
      with pkgs; [

        nodejs
        git
        curl
        icu
        openssl
        zlib
        dotnet-sdk
        dotnet-runtime
        dotnet-aspnetcore
        lttng-ust
        krb5
        libffi
        glibc
        libgcc
        libstdcxx5
        azure-cli
      ];
    runScript = "bash";
  };

  main = pkgs.writeShellApplication {
    inherit name;
    text = ''
      ADO_AGENT_DIR="''${ADO_AGENT_DIR:-/var/lib/ado-agent}"
      if [ -f "$ADO_AGENT_DIR/.credentials" ]; then
          echo ".credentials file exists. Running run.sh..."
          ${run-script}/bin/run.sh
      else
          echo ".credentials file does not exist. Running config.sh, then run.sh..."
          ${config-script}/bin/config.sh && ${run-script}/bin/run.sh
      fi
    '';
  };

  # just a wrapper around the run script
  run-script = pkgs.writeShellApplication {
    name = "run.sh";
    runtimeInputs = [
      pkgs.gnutar
      pkgs.gzip
      pkgs.docker
      pkgs.azure-storage-azcopy
      pkgs.azure-cli
      pkgs.jq
      pkgs.nix
    ];
    text = ''
      ADO_AGENT_DIR="''${ADO_AGENT_DIR:-/var/lib/ado-agent}"
      ${fhsEnv}/bin/ado-pipeline-agent "$ADO_AGENT_DIR"/run.sh "$@"
    '';
  };

  config-script = pkgs.writeShellApplication {
    name = "config.sh";
    runtimeInputs = [
      pkgs.gnutar
      pkgs.gzip
      pkgs.docker
      pkgs.azure-storage-azcopy
      pkgs.azure-cli
      pkgs.jq
      pkgs.nix
    ];
    text = ''
      deleteAgentDir=false
      ADO_PAT="''${ADO_PAT:-}"
      ADO_POOL_NAME="''${ADO_POOL_NAME:-campground}"
      ADO_AGENT_NAME="''${ADO_AGENT_NAME:-campground_agent}"
      ADO_AGENT_DIR="''${ADO_AGENT_DIR:-/var/lib/ado-agent}"
      ADO_URL="''${ADO_URL:-https://dev.azure.com/campground}"

      while [ $# -gt 0 ]; do
          case "$1" in
              --pat) ADO_PAT="$2"; shift 2;;
              -p) ADO_PAT="$2"; shift 2;;
              --pool-name) ADO_POOL_NAME="$2"; shift 2;;
              -n) ADO_POOL_NAME="$2"; shift 2;;
              --agent-name) ADO_AGENT_NAME="$2"; shift 2;;
              -a) ADO_AGENT_NAME="$2"; shift 2;;
              --agent-dir) ADO_AGENT_DIR="$2"; shift 2;;
              -d) ADO_AGENT_DIR="$2"; shift 2;;
              --help) echo "Usage: $0 [-p PAT] [-n <pool_name>] [-a <agent_name>] [-d <agent_dir>]"; exit 0;;
              *) break ;;
          esac
      done

      if [ -n "$ADO_POOL_NAME" ] && [ -z "$ADO_AGENT_DIR" ]; then
        echo "Error: pool-name must be specified"
        exit 1
      fi

      if [ -z "$ADO_PAT" ] || [ -z "$ADO_POOL_NAME" ] || [ -z "$ADO_AGENT_NAME" ] || { [ -n "$deleteAgentDir" ] && [ -z "$ADO_AGENT_DIR" ]; }; then
        echo "Error: All required arguments must be provided"
        exit 1
      fi

      ${pkgs.gnutar}/bin/tar -xzf ${src} -C "$ADO_AGENT_DIR"

      if [ -n "$ADO_POOL_NAME" ] && [ -n "$ADO_AGENT_NAME" ]; then
        chmod +x "$ADO_AGENT_DIR"/config.sh
        ${fhsEnv}/bin/ado-pipeline-agent "$ADO_AGENT_DIR"/config.sh \
          --unattended \
          --url "$ADO_URL" \
          --auth pat \
          --token "$ADO_PAT" \
          --pool "$ADO_POOL_NAME" \
          --agent "$ADO_AGENT_NAME" \
          --replace \
          --acceptTeeEula
      else
        echo "Error: pool-name and agent-name arguments are required"
        exit 1
      fi
    '';
  };

in main // {
  config = config-script;
  run = run-script;
  fhs = fhsEnv;
  src = src;
}
