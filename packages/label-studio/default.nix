{
  config,
  lib,
  dream2nix,
  ...
}: let

  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  label-studio-src = config.deps.fetchFromGitHub {
      owner = "HumanSignal";
      repo = "label-studio";
      rev = "f931d9d129002f54a495995774ce7384174cef5c";
      forceFetchGit = true;
      hash = "sha256-8eWaSgRG8KI+KePIRTMU//LePFlnE0t0b/QhOMpk3M0=";
    };
  core = builtins.path {
    name = "label-studio-with-core";
    path = ./.;
  };
in {
  imports = [
    dream2nix.modules.dream2nix.pip

  ];

  deps = {
    nixpkgs,
    nixpkgsStable,
    ...
  }: {
    inherit
      (nixpkgs)
      git
      fetchFromGitHub
      mysql
      postgresql
      dbus
      uwsgi
      python310Packages
      ;
    python = nixpkgs.python310;
  };

  name = "label_studio";
  version = "1.9.2.post0";

  buildPythonPackage = {
    catchConflicts = true;
    pythonImportsCheck = [
      config.name
    ];
    # format = "pyproject";
  };

  mkDerivation = {
    src = label-studio-src;
    preBuild = ''
      cd ./label_studio
      rm -rf core
      ls -lah ${core}
      cp -r ${core}/core ./core
      cd ..
      python label_studio/core/version.py
    '';
    postInstall = ''
      export PYTHONEXEC=$(python -c "import django; import sys; print(sys.executable)")
      mkdir -p $out/etc
      echo "#!/bin/sh" > $out/bin/label-studio-guni
      echo "export DJANGO_SETTINGS_MODULE=core.settings.label_studio" >> $out/bin/label-studio-guni
      echo "export PYTHONPATH=$out/lib/python3.10/site-packages:$PYTHONPATH" >> $out/bin/label-studio-guni
      echo "${config.deps.python310Packages.gunicorn}/bin/gunicorn --chdir $out/lib/python3.10/site-packages/label_studio core.wsgi:application -b :8080 -w 4" >> $out/bin/label-studio-guni  
      chmod +x $out/bin/label-studio-guni
    '';
  };

  pip = {
    pipVersion = "23.3.1";
    pypiSnapshotDate = "2023-11-11";
    flattenDependencies = true;
    requirementsList = [
      "gunicorn"
      "appdirs==1.4.4"
      "asgiref==3.7.2"
      "attrs==23.1.0"
      "azure-core==1.29.4"
      "azure-storage-blob==12.18.3"
      "bleach==5.0.1"
      "boto==2.49.0"
      "boto3==1.28.58"
      "botocore==1.31.58"
      "boxing==0.1.4"
      "cachetools==5.3.1"
      "certifi==2023.7.22"
      "cffi==1.16.0"
      "charset-normalizer==3.3.0"
      "click==8.1.7"
      "colorama==0.4.6"
      "cryptography==41.0.4"
      "defusedxml==0.7.1"
      "Django==3.2.20"
      "django-annoying==0.10.6"
      "django-cors-headers==3.6.0"
      "django-debug-toolbar==3.2.1"
      "django-environ==0.10.0"
      "django-extensions==3.1.0"
      "django-filter==2.4.0"
      "django-model-utils==4.1.1"
      "django-ranged-fileresponse==0.1.2"
      "django-rq==2.5.1"
      "django-storages==1.12.3"
      "django-user-agents==0.4.0"
      "djangorestframework==3.13.1"
      "drf-dynamic-fields==0.3.0"
      "drf-flex-fields==0.9.5"
      "drf-generators==0.3.0"
      "expiringdict==1.2.2"
      "google-api-core==2.11.0"
      "google-auth==2.14.1"
      "google-cloud-appengine-logging==1.1.0"
      "google-cloud-audit-log==0.2.0"
      "google-cloud-core==2.3.2"
      "google-cloud-logging==2.7.2"
      "google-cloud-storage==2.5.0"
      "google-crc32c==1.5.0"
      "google-resumable-media==2.3.3"
      "googleapis-common-protos==1.56.4"
      "grpc-google-iam-v1==0.12.4"
      "grpcio==1.59.0"
      "grpcio-status==1.48.2"
      "htmlmin==0.1.12"
      "humansignal-drf-yasg==1.21.9"
      "idna==3.4"
      "ijson==3.2.3"
      "inflection==0.5.1"
      "isodate==0.6.1"
      "jmespath==0.10.0"
      "joblib==1.3.2"
      "jsonschema==3.2.0"
      "label-studio-converter==0.0.57"
      "label-studio-tools==0.0.3"
      "launchdarkly-server-sdk==7.5.0"
      "lockfile==0.12.2"
      "lxml==4.9.3"
      "nltk==3.6.7"
      "numpy==1.24.3"
      "ordered-set==4.0.2"
      "packaging==23.2"
      "pandas==2.1.1"
      "Pillow==10.0.1"
      "proto-plus==1.22.3"
      "protobuf==3.20.3"
      "psycopg2-binary==2.9.6"
      "pyasn1==0.5.0"
      "pyasn1-modules==0.3.0"
      "pycparser==2.21"
      "pydantic==1.10.13"
      "pyRFC3339==1.1"
      "pyrsistent==0.19.3"
      "python-dateutil==2.8.2"
      "python-json-logger==2.0.4"
      "pytz==2022.7.1"
      "PyYAML==6.0.1"
      "redis==3.5.3"
      "regex==2023.10.3"
      "requests==2.31.0"
      "rq==1.10.1"
      "rsa==4.9"
      "rules==2.2"
      # "s3transfer==0.3.7"
      "semver==2.13.0"
      "sentry-sdk==1.32.0"
      "six==1.16.0"
      "sqlparse==0.4.4"
      "tqdm==4.66.1"
      "typing_extensions==4.8.0"
      "tzdata==2023.3"
      "ua-parser==0.18.0"
      "ujson==5.8.0"
      "uritemplate==4.1.1"
      "urllib3==1.26.17"
      "user-agents==2.2.0"
      "uWSGI==2.0.22"
      "uwsgitop==0.11"
      # "webencodings==0.5.1"
      "xmljson==0.2.0"
    ];
  };
}
