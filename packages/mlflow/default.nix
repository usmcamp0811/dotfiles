{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, system
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  inherit system;
  pname = "mlflow";

  description = "MLFlow hack job";

  version = "2.3.2";

  mlflow = pkgs.python311Packages.toPythonApplication (pkgs.python311Packages.mlflow.overridePythonAttrs(old: rec {

    propagatedBuildInputs = old.propagatedBuildInputs ++ [
      pkgs.python311Packages.boto3
      pkgs.python311Packages.psycopg2
      pkgs.python311Packages.mysqlclient
      pkgs.python311Packages.gunicorn
    ];

    postPatch = ''
      substituteInPlace mlflow/utils/process.py --replace \
        "child = subprocess.Popen(cmd, env=cmd_env, cwd=cwd, universal_newlines=True," \
        "cmd[0]='$out/bin/gunicornMlflow'; child = subprocess.Popen(cmd, env=cmd_env, cwd=cwd, universal_newlines=True,"
    '';

    gunicornScript = writeText "gunicornMlflow"
    ''
        #!${pkgs.python311}/bin/python
        import re
        import sys
        from gunicorn.app.wsgiapp import run

        if __name__ == '__main__':
          sys.argv[0] = re.sub(r'(-script\.pyw|\.exe)?$', ''', sys.argv[0])
          sys.exit(run())
      '';

    postInstall = ''
      gpath=$out/bin/gunicornMlflow
      cp ${gunicornScript} $gpath
      echo "#!/bin/sh" > $out/bin/mlflow-server
      echo "export PYTHONPATH=$out/lib/python3.11/site-packages:$PYTHONPATH" >> $out/bin/mlflow-server
      echo "export PATH=$out/bin:$PATH" >> $out/bin/mlflow-server
      echo "mlflow \"\$@\"" >> $out/bin/mlflow-server
      chmod 555 $gpath
      chmod 555 $out/bin/mlflow-server
    '';
  }));
  new-meta = with lib; {
    description = description;
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta mlflow
