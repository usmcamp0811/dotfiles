# The backend's Python dependencies as a directory of wheels.
#
# A fixed-output derivation: it may use the network, but only to fetch files whose
# sha256 are listed in requirements.lock.txt (pip --require-hashes refuses anything
# else), and the resulting directory must match `hash`. Nothing here is "latest": the
# versions and file hashes come from upstream's poetry.lock via gen-lock.py.
{
  lib,
  stdenvNoCC,
  python312,
  cacert,
  hash ? "sha256-pUj8gx7gnwQx3HCL5oIRJ0hTbkR2USBgAQcEg+RaBFA=",
}:
stdenvNoCC.mkDerivation {
  name = "circuit-breaker-wheelhouse";
  nativeBuildInputs = [python312.pkgs.pip cacert];
  dontUnpack = true;
  dontConfigure = true;
  dontFixup = true;

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    mkdir -p $out
    platforms=""
    for p in manylinux_2_34 manylinux_2_31 manylinux_2_28 manylinux_2_27 manylinux_2_17 manylinux2014 manylinux_2_5 manylinux1 linux; do
      platforms="$platforms --platform ''${p}_x86_64"
    done
    python -m pip download \
      --no-deps --only-binary=:all: --require-hashes --disable-pip-version-check \
      --python-version 3.12 --implementation cp --abi cp312 --abi abi3 --abi none \
      $platforms --platform any \
      -r ${./requirements.lock.txt} -d $out
    runHook postBuild
  '';
  dontInstall = true;

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = hash;

  meta.description = "Hash-pinned wheels for the Circuit Breaker backend";
}
