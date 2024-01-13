{ lib, pkgs, ... }:

with lib;

{
  name = "docker-version";

  machine = { ... }: {
    virtualisation.memorySize = 1024;
    virtualisation.diskSize = 1024;
    services.docker.enable = true;
  };

  testScript = ''
    startAll;
    $machine->waitForUnit("docker.service");
    $machine->succeed("docker --version") =~ "Docker version 24.0.5, build v24.0.5";
  '';
}

