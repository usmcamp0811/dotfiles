{ channels, comma, ... }:

final: prev:
{
  # Depends on PR merged into main, but not yet in a release tag.
  # See: https://github.com/containerd/containerd/pull/9028
  containerd = prev.containerd.overrideAttrs(o: {
    src = final.fetchFromGitHub {
      inherit (o.src) owner repo;
      rev = "779875a057ff98e9b754371c193fe3b0c23ae7a2";
      hash = "sha256-sXMDMX0QPbnFvRYrAP+sVFjTI9IqzOmLnmqAo8lE9pg=";
    };
  });
}
