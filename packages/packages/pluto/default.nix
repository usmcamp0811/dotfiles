{ lib, pkgs, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.fmf) override-meta;
  julia-env = pkgs.julia.withPackages.override
    {
      extraLibs =
        [ pkgs.libxcrypt pkgs.libxcrypt-legacy pkgs.openssl pkgs.cyrus_sasl ];
      setDefaultDepot = true;
    } [ "Pluto" "PythonCall" ];
in
pkgs.writeShellApplication {
  name = "pluto";
  meta = { mainProgram = "pluto"; };
  runtimeInputs = [ julia-env pkgs.gcc13 ];
  text = ''
    HOST="0.0.0.0" # Default host
    PORT=1234      # Default port

    # Parse command-line arguments for --host and --port
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --host) HOST="$2"; shift ;;
            --port) PORT="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; exit 1 ;;
        esac
        shift
    done

    julia -e "using Pluto; Pluto.run(host=\"$HOST\", port=$PORT)"
  '';
}
