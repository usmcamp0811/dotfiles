{ lib, stdenv, fetchFromGitHub, fetchurl, curl, autoconf, automake, cmake
, libtool, patch, perl, policycoreutils, python312, zstd, patchelf, systemd
, removeReferencesTo, libgcc, target, installType, pname, version ? "4.9.1"
, srcHash ? "sha256-OiNwKX/bGjh9e7EQ/8ylY2SSjifqu9vfpne9mvHvEmM="
, dependencyVersion ? "30", dependencyHashes ? {
  cJSON = "678d796318da57d5f38075e74bbb3b77375dc3f8bb49da341ad1b43c417e8cc1";
  curl = "sha256-QBUdS8paLByEDtIkNx/g2VFSMXalvDxNA2Lz2m+WZUA=";
  libdb = "sha256-fpxE6Mf9sYb/UhqNCFsb+mNNNC3Md37Oofv5qYq13F4=";
  libffi = "sha256-DpcfZLrMIglOifA0u6B1tA7MLCwpAO7NeuhYFf1sn2k=";
  libyaml = "sha256-NdqtYIs3LVzgmfc4wPIb/MA9aSDZL0SDhsWE5mTxN2o=";
  openssl = "sha256-I4QVZBEgyPednBwsr5e4jT1tvtVihZ3QZjvUto3CF54=";
  procps = "sha256-Ih85XinRvb5LrMnbOWAu7guuaFqTVDe+DX/rQuMZLQc=";
  sqlite = "sha256-mo+mqRb4whB+1l2rjc7TkmBOF1EE1qjDycE4NHmGnwc=";
  zlib = "sha256-tZ04FJ8MKexU0nZmEevFpRoDK/lxfjmprwD7bLhTK4s=";
  audit-userspace = "sha256-6Coy5e35OwVRYOFLyX9B3q05KHklhR3ICnY44tTTBDQ=";
  msgpack = "sha256-BtY7zzKJbNCvVIDEARNLGtHBZv2E6+W0hueSEB7oVOI=";
  bzip2 = "sha256-J2iO4DFqZLOeURssIkBwytl8OUpfcR+dBV/BgJ2JW80=";
  nlohmann = "sha256-zvsHk209W/3T78Xpu408gH1oEnO9rC6Ds9Z67y0RWMQ=";
  googletest = "sha256-jB6KCn8iHCEl6Z5qy3CdorpHJHa00FfFjeUEvr841Bc=";
  libpcre2 = "sha256-WoDWVNfRSz25+jpJ179EpJhoO0Z4SojOxRSosZR2e5I=";
  libplist = "sha256-iCeNS9/BvWo6GlWk89kzaD0nMroJz3p0n+jsjuxAbjw=";
  pacman = "sha256-9n3Tiir7NA19YDUNSbdamDp8TgGtdgIFaSDv6EnVsUM=";
  libarchive = "sha256-yVgEgXXa1aE9CFHQPHwaNjYeEujpPnQywYROlUnd9Yo=";
  popt = "sha256-1ogKBmIsoy3EqjmtXc977y+qgb2TGvvmS6Q0rY/uHao=";
  rpm = "sha256-rvwlMB7M8irFHL2BOn89RHHxxCYYFy7lSKKbGVmsW68=";
  rocksdb = "sha256-7u1go9Tin3MF55+fXOvUJhF0JhIn8bWn0F2lVWVnVDY=";
  lzma = "sha256-TODBktQQcrVnmvibtTHvtoXIJnpLfiAFmZFJrBcCgTQ=";
  cpp-httplib = "sha256-ZRdXMmNhFoa5IZunlsNfVKMG6yfcPHLhgH8qCjTKweg=";
  benchmark = "sha256-lMV6oMsr142+nnfTMsvGRNrw/s3JoJYyBIvm4J+c7Ws=";
  lua = "sha256-Yu634kskbFBwi81Nkts8nejRltlMnDO4v/QA8l8QWh8=";
  cpython = "sha256-wDZPE1+nKM5bG75ht35mV0PvQ7yYTy7hbW5+QumacHY=";
  jemalloc = "sha256-KyLoWzUsffVQukCKQiUeUejf+myRqi4ftIBKsxf/vKA=";
  flatbuffers = "sha256-lDaZof6GwZc3HNIUxMNV2g8lOjCT8Mc/t0y0xIuJeKk=";
}, wazuhHttpRequestRev ? "8a302e514de6ef4df86717027682922f705330f4"
, wazuhHttpRequestHash ? "sha256-lXi/2qQV3v3mikR2SxK0DMpTuw8Dqka5SccA0xMnP0s="
, ... }:
let
  fetcher = name: sha256:
    fetchurl {
      url =
        "https://packages.wazuh.com/deps/${dependencyVersion}/libraries/sources/${name}.tar.gz";
      inherit sha256;
    };

  dependencies = map (name: fetcher name dependencyHashes.${name})
    (builtins.attrNames dependencyHashes);

  wazuh-http-request = fetchFromGitHub {
    owner = "wazuh";
    repo = "wazuh-http-request";
    rev = wazuhHttpRequestRev;
    hash = wazuhHttpRequestHash;
  };
in stdenv.mkDerivation rec {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "wazuh";
    repo = "wazuh";
    rev = "v${version}";
    sha256 = srcHash;
  };

  enableParallelBuilding = true;
  dontConfigure = true;
  dontFixup = true;

  nativeBuildInputs = [
    curl
    autoconf
    automake
    cmake
    libtool
    perl
    policycoreutils
    python312
    zstd
  ];

  makeFlags = [ "-C src" "TARGET=${target}" "INSTALLDIR=$out" ];

  unpackPhase = ''
    runHook preUnpack

    cp -rf --no-preserve=all "$src"/* .

    mkdir -p src/external
    ${lib.strings.concatMapStringsSep "\n"
    (dep: "tar -xzf ${dep} -C src/external") dependencies}

    cp --no-preserve=all -rf ${wazuh-http-request}/* src/shared_modules/http-request/

    runHook postUnpack
  '';

  patchPhase = ''
    runHook prePatch

    ${patch}/bin/patch -p1 < ${./makefile-patch-1.patch}

    substituteInPlace src/init/wazuh-server.sh \
      --replace-fail "cd ''${LOCAL}" ""

    substituteInPlace src/external/audit-userspace/autogen.sh \
      --replace-warn "cp INSTALL.tmp INSTALL" ""

    substituteInPlace src/external/openssl/config \
      --replace-warn "/usr/bin/env" "env"

    touch src/external/cpython.tar

    cat << EOF > "etc/preloaded-vars.conf"
    USER_LANGUAGE="en"
    USER_NO_STOP="y"
    USER_INSTALL_TYPE="${installType}"
    USER_DIR="$out"
    USER_DELETE_DIR="n"
    USER_ENABLE_ACTIVE_RESPONSE="y"
    USER_ENABLE_SYSCHECK="y"
    USER_ENABLE_ROOTCHECK="y"
    USER_ENABLE_OPENSCAP="y"
    USER_ENABLE_SYSCOLLECTOR="y"
    USER_ENABLE_SECURITY_CONFIGURATION_ASSESSMENT="y"
    ${lib.optionalString (installType == "agent") ''
      USER_AGENT_SERVER_IP=127.0.0.1
      USER_CA_STORE="no"
    ''}
    EOF

    runHook postPatch
  '';

  preBuild = ''
    make -C src TARGET=${target} INSTALLDIR=$out deps
  '';

  installPhase = ''
    mkdir -p $out/{bin,etc,active-response,queue,var,wodles,logs,lib,tmp}

    substituteInPlace install.sh \
      --replace-warn "Xroot" "Xnixbld"
    chmod u+x install.sh

    substituteInPlace src/init/inst-functions.sh \
      --replace-warn "WAZUH_GROUP='wazuh'" "WAZUH_GROUP='nixbld'" \
      --replace-warn "WAZUH_USER='wazuh'" "WAZUH_USER='nixbld'"

    INSTALLDIR=$out USER_DIR=$out ./install.sh binary-install

    substituteInPlace $out/bin/wazuh-control \
      --replace-fail "cd ''${LOCAL}" "#"

    chmod u+x $out/bin/* $out/active-response/bin/*

    ${removeReferencesTo}/bin/remove-references-to \
      -t ${libgcc.out} \
      $out/lib/* || true

    if [ -f "$out/bin/wazuh-logcollector" ]; then
      ${patchelf}/bin/patchelf --add-rpath ${systemd}/lib $out/bin/wazuh-logcollector
    fi

    rm -rf $out/src
  '';

  meta = with lib; {
    description = "Wazuh ${installType} package";
    homepage = "https://wazuh.com";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
