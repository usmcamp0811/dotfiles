{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "pluto";
  julia-env = pkgs.julia.withPackages [ "Pluto" "PythonCall"];
  pluto = pkgs.writeShellScriptBin "pluto" ''
    #!/usr/bin/env bash
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

    ${julia-env}/bin/julia -e "using Pluto; Pluto.run(host=\"$HOST\", port=$PORT)"
  '';

  new-meta = with lib; {
    description = "Pluto.jl";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };

in
override-meta new-meta pluto
