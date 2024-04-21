{ traefik, ... }:
final: prev: {
  traefik = prev.traefik.overrideAttrs (oldAttrs: {
    postInstall = oldAttrs.postInstall or ''
      mkdir -p $out/bin/plugins-local/src/github.com/Amadeus331/
      cp -r ${
        prev.fetchFromGitHub {
          owner = "Amadeus331";
          repo = "cloudflarewarp";
          rev = "d48521728cfb97c59d14dc2958d99c8949e2beba";
          sha256 = "sha256-vIWHWwsXSuuETUerOBLxzHWkx1Q0Onw4SgvOw4GCCck=";
        }
      } $out/bin/plugins-local/src/github.com/Amadeus331/cloudflarewarp
    '';
  });
}
