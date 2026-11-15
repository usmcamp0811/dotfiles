{
  pkgs,
  lib,
  # CUDA compute capabilities to compile for. 89 is Ada (RTX 40, e.g. the 4070 Ti SUPER in sledge). More
  # architectures cost compile time, so the default is one card; override per host.
  cudaArchitectures ? ["89"],
  # STRATA_PORTABLE=ON is what upstream's own ready-made Linux engine uses: ggml-cpu at an AVX2 baseline. The
  # alternative (OFF) is -march=native, which in a Nix build means "the CPU of whichever farm machine compiled
  # it", not the machine that runs it. Strata's own AVX-512 kernels are per-file and chosen at run time either way.
  portable ? true,
  ...
}: let
  # Strata upstream: https://github.com/Niko1221/Strata (MIT). Tag v0.2.13.1 = Control 0.1.59.1; the app/terminal
  # version is 0.2.13 and the engine 0.1.59 (AGENTS.md, docs/AI_REFERENCE.md at this commit).
  rev = "628f74955a56fcba092495b800dd02af75373a0f";
  version = "0.2.13.1";

  src = pkgs.fetchFromGitHub {
    owner = "Niko1221";
    repo = "Strata";
    inherit rev;
    hash = "sha256-nQ3Jdui9y6r5FqsEoJraKsqBLeCTRRERU0zS8CQTqSY=";
  };

  # setup.py (LLAMA_CPP_COMMIT) builds the engine against this llama.cpp (ggml) and takes gguf-py from it. The
  # tree also vendors ggml (third_party/strata-ggml, used when STRATA_GGML_DIR is empty); matching upstream's
  # own build means using the pinned llama.cpp.
  llamaCpp = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "3cf03257f219afbe7334045ff7c6a06ac68c627d";
    hash = "sha256-SRGoXa+4ACBCB3eaG9XFYhMN1i0FyPEy9Rrer+dFGYI=";
  };

  # setup.py and upstream's flake.nix want CUDA 13.0 ("13.2.0/13.2.1 miscompile for sm_120"). CUDA 13 needs
  # NVIDIA driver 580 or newer at run time.
  cudaPackages = pkgs.cudaPackages_13_0;
  stdenv = cudaPackages.backendStdenv;
  cuda = cudaPackages.cudatoolkit;

  # Runtime Python packages of upstream's requirements.txt. Upstream pins exact versions; nixpkgs' versions
  # are what is used here.
  py = pkgs.python3.withPackages (ps:
    with ps; [numpy jinja2 regex pyyaml tqdm requests pillow psutil certifi truststore]);

  engine = stdenv.mkDerivation {
    pname = "strata-engine";
    inherit version src;

    nativeBuildInputs = [pkgs.cmake pkgs.ninja cuda pkgs.autoAddDriverRunpath];
    buildInputs = [cuda];

    # Not a flake-style source build: upstream's CMake has no install() rules, so the phases are explicit.
    dontUseCmakeConfigure = false;
    cmakeFlags =
      [
        "-DCMAKE_BUILD_TYPE=Release"
        "-DSTRATA_ENABLE_CUDA=ON"
        "-DSTRATA_BUILD_TESTS=OFF"
        # the same switches setup.py's build_engine passes: Q6_K expert kernels (UD-Q6_K_XL) and the K-quant MMQ
        # prompt kernels (libstrata_kq.so, which every Unsloth K-quant file needs next to the engine)
        "-DSTRATA_Q6K_EXPERTS=ON"
        "-DSTRATA_MMQ_KQUANTS=ON"
        "-DSTRATA_GGML_DIR=${llamaCpp}"
        "-DCMAKE_CUDA_ARCHITECTURES=${lib.concatStringsSep ";" cudaArchitectures}"
        "-DCMAKE_CUDA_COMPILER=${cuda}/bin/nvcc"
        "-DCUDAToolkit_ROOT=${cuda}"
        "-DCMAKE_CUDA_HOST_COMPILER=${stdenv.cc}/bin/c++"
      ]
      ++ lib.optional portable "-DSTRATA_PORTABLE=ON";

    env = {
      CUDA_HOME = "${cuda}";
      CUDA_PATH = "${cuda}";
    };

    buildPhase = ''
      runHook preBuild
      cmake --build . --target strata strata_kq -j "$NIX_BUILD_CORES"
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec/strata
      install -m755 strata $out/libexec/strata/strata
      # the K-quant library goes next to the engine, as setup.py copies it
      install -m755 libstrata_kq.so $out/libexec/strata/libstrata_kq.so
      runHook postInstall
    '';

    # Stripping can damage the embedded CUDA fat binaries.
    dontStrip = true;

    meta = {
      description = "Strata inference engine (CUDA ${cudaPackages.cudaMajorMinorVersion}) for sm_${lib.concatStringsSep "/" cudaArchitectures}";
      homepage = "https://github.com/Niko1221/Strata";
      license = [lib.licenses.mit lib.licenses.unfreeRedistributable];
      platforms = ["x86_64-linux"];
    };
  };

  # What the server needs at run time: the Python server, its control library, the tokenizer tools.
  root = pkgs.runCommand "strata-server-root-${version}" {} ''
    mkdir -p $out
    for d in serve strata_control strata_cli tools data; do
      [ -e ${src}/$d ] && cp -r ${src}/$d $out/$d
    done
    cp ${src}/*.py $out/
    cp ${src}/LICENSE $out/
    chmod -R u+w $out
  '';

  # ---- DeepSeek V4.1: its own engine binary ----
  # Upstream builds strata-dsv41 as a second CMake target in its own build directory (packaging/build_dsv41_cuda.sh)
  # and the Python server picks it by the run config's "exe". It is a separate derivation here for the same reason:
  # one configure that builds `strata`, `strata_kq` and `strata-dsv41` together is not something upstream documents.
  # The flags are that script's. STRATA_BUILD_ID is what a tarball without .git needs for `--version`.
  engineDsv41 = stdenv.mkDerivation {
    pname = "strata-engine-dsv41";
    inherit version src;

    nativeBuildInputs = [pkgs.cmake pkgs.ninja cuda pkgs.autoAddDriverRunpath];
    buildInputs = [cuda];

    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DSTRATA_ENABLE_CUDA=ON"
      "-DSTRATA_BUILD_TESTS=OFF"
      "-DSTRATA_BUILD_DSV41=ON"
      "-DSTRATA_NATIVE_EXPERTS=ON"
      "-DSTRATA_PORTABLE=ON"
      "-DSTRATA_BUILD_ID=${builtins.substring 0 9 rev}"
      "-DSTRATA_GGML_DIR=${llamaCpp}"
      "-DCMAKE_CUDA_ARCHITECTURES=${lib.concatStringsSep ";" cudaArchitectures}"
      "-DCMAKE_CUDA_COMPILER=${cuda}/bin/nvcc"
      "-DCUDAToolkit_ROOT=${cuda}"
      "-DCMAKE_CUDA_HOST_COMPILER=${stdenv.cc}/bin/c++"
    ];

    env = {
      CUDA_HOME = "${cuda}";
      CUDA_PATH = "${cuda}";
    };

    buildPhase = ''
      runHook preBuild
      cmake --build . --target strata-dsv41 -j "$NIX_BUILD_CORES"
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec/strata
      install -m755 strata-dsv41 $out/libexec/strata/strata-dsv41
      runHook postInstall
    '';

    dontStrip = true;

    meta = {
      description = "Strata DeepSeek V4.1 engine (CUDA ${cudaPackages.cudaMajorMinorVersion}) for sm_${lib.concatStringsSep "/" cudaArchitectures}";
      homepage = "https://github.com/Niko1221/Strata";
      license = [lib.licenses.mit lib.licenses.unfreeRedistributable];
      platforms = ["x86_64-linux"];
    };
  };

  # ---- model files that are not one GGUF ----
  # A model with several shards is read by name: the engine and the pack tools look for <name>-0000N-of-0000M.gguf
  # beside the file they are given, without resolving symlinks. The store names of the shards are content-named (one
  # store path for a file that several sets share), so each model gets a directory of symlinks under the sibling
  # names. The farm is what the packs record and the run config points at.
  farmFor = id: model:
    pkgs.linkFarm "strata-shards-${id}" (map (f: {
        inherit (f) name path;
      })
      model.files);

  # Qwen3.8-Flash-Next (ISTA-DASLab, Coder, Unsloth): setup.py step 6 runs tools/iq_pack.py on shard 1. It writes the
  # pack (index, dense weights, expert map, tokenizer) beside nothing: the experts stay in the GGUF shards and the
  # engine reads them from there. CPU only, no network.
  packFlashNext = id: model:
    pkgs.runCommand "strata-pack-${id}" {
      nativeBuildInputs = [py];
      STRATA_GGUF_PY = "${llamaCpp}/gguf-py";
    } ''
      ${py}/bin/python ${root}/tools/iq_pack.py --gguf ${farmFor id model}/${model.native} --out $out ${lib.escapeShellArgs model.packArgs}
    '';

  # DeepSeek V4.1: setup.py's dsv41_pack_cmd, "this and nothing else" (another recipe packs without an error and gives
  # garbage text, upstream's note). Writes the geometry, tensor map, Engram hash tables and tokenizer: no weights are
  # copied. The shipped hot-expert profile goes in as expert-profile.bin; the engine saves routing counts back to it
  # unless --profile-readonly, which the module passes because a pack in the store cannot be written.
  packDeepseek = id: model:
    pkgs.runCommand "strata-pack-${id}" {
      nativeBuildInputs = [py];
      STRATA_GGUF_PY = "${llamaCpp}/gguf-py";
    } ''
      ${py}/bin/python ${root}/tools/dsv41/pack_gguf.py --model ${farmFor id model} \
        --shards ${lib.escapeShellArgs (map (f: f.name) model.files)} \
        --engram ${model.engram} --engram-meta ${model.meta} --dspark-gguf ${model.dspark} \
        --dspark-noise-token 128799 --dspark-markov-rank 256 --out $out
      cp ${root}/data/dsv41/${model.profile} $out/expert-profile.bin
    '';

  # ---- the MTP draft layer of Qwen3.8-Flash-Next ----
  # The GSQ-RCO and Unsloth GGUFs ship no MTP head. Upstream's tools/mtp_fetch.py reads its 31 tensors from the BF16
  # checkpoint with HTTP range requests (5.21 GB of 360 GB) and pins the SHA-256 of every one at one revision of that
  # repository. The fixed-output derivation below reads the same ranges, in the same order as mtp-tensors.json
  # (sorted by tensor name), into one file; its hash was computed by streaming those ranges once. Each range is read
  # in 256 MiB parts that are retried alone, because a retry in the middle of a stream would duplicate bytes.
  mtpTensors = builtins.fromJSON (builtins.readFile ./mtp-tensors.json);
  mtpBlob = pkgs.runCommand "strata-mtp-blob" {
    nativeBuildInputs = [pkgs.curl pkgs.coreutils];
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = "sha256-FENky+a6xaqIHA2Qczc8ACk+c6aHuiVT8yzON1nxlDk=";
  } ''
    fetch() { # shard, first byte, length
      pos=$2; last=$(( $2 + $3 - 1 ))
      while [ "$pos" -le "$last" ]; do
        e=$(( pos + 268435455 )); [ "$e" -gt "$last" ] && e=$last
        want=$(( e - pos + 1 )); try=0
        while :; do
          rm -f chunk
          if curl -fsSL --connect-timeout 30 --max-time 900 -r "$pos-$e" \
               "https://huggingface.co/${mtpTensors.repository}/resolve/${mtpTensors.revision}/$1" -o chunk \
             && [ "$(stat -c %s chunk)" -eq "$want" ]; then break; fi
          try=$(( try + 1 ))
          if [ "$try" -ge 8 ]; then echo "range $pos-$e of $1 failed" >&2; exit 1; fi
          sleep $(( try * 3 ))
        done
        cat chunk >> "$out"; rm -f chunk
        pos=$(( e + 1 ))
      done
    }
    : > "$out"
    ${lib.concatMapStrings (t: "fetch ${t.shard} ${toString t.start} ${toString t.bytes}\n") mtpTensors.tensors}
  '';

  # tools/mtp_pack.py (the experts to Q2_0, CPU numpy) then tools/mtp_rt.py (the engine's runtime layout), then the
  # draft vocabulary setup.py copies into the folder (the default subset, "cjk"). Each tensor is split out of the blob
  # and checked against mtp_fetch.py's pinned SHA-256 before it is used. The result is the folder `--mtp` names.
  mtpRt =
    pkgs.runCommand "strata-mtp-rt" {
      nativeBuildInputs = [py pkgs.coreutils];
      STRATA_GGUF_PY = "${llamaCpp}/gguf-py";
    } ''
      mkdir -p work/tensors
      ${lib.concatMapStrings (t: ''
          dd if=${mtpBlob} of=work/tensors/${t.name}.bin bs=1M iflag=skip_bytes,count_bytes skip=${toString t.offset} count=${toString t.bytes} status=none
          echo "${t.sha256}  work/tensors/${t.name}.bin" | sha256sum -c --quiet -
        '')
        mtpTensors.tensors}
      cp ${pkgs.writeText "mtp-manifest.json" (builtins.toJSON (map (t: {
          inherit (t) name shape sha256;
          file = "tensors/${t.name}.bin";
        })
        mtpTensors.tensors))} work/mtp-manifest.json
      ${py}/bin/python ${root}/tools/mtp_pack.py --src work --experts q2_0 --out work/mtp-q2_0.gguf
      ${py}/bin/python ${root}/tools/mtp_rt.py --gguf work/mtp-q2_0.gguf --out $out
      cp ${root}/data/draft_vocab.bin $out/draft_vocab.bin
    '';
in
  pkgs.runCommand "strata-${version}" {
    inherit version;
    passthru = {
      inherit engine engineDsv41 root py llamaCpp src rev cudaArchitectures;
      inherit farmFor packFlashNext packDeepseek mtpBlob mtpRt;
      # exe of the engine, as the run config's "exe" wants it
      enginePath = "${engine}/libexec/strata/strata";
      # the DeepSeek V4.1 engine, a different binary (run config arch "deepseek41")
      enginePathDsv41 = "${engineDsv41}/libexec/strata/strata-dsv41";
      # Extract the tokenizer (vocab, merges, chat template) from a GGUF's metadata, as setup.py's step 6 does.
      # A pure derivation instead of a conversion at service start. Result: <out>/tokenizer.
      tokenizerFor = gguf:
        pkgs.runCommand "strata-tokenizer-${gguf.name or "model"}" {
          nativeBuildInputs = [py];
          STRATA_GGUF_PY = "${llamaCpp}/gguf-py";
        } ''
          ${py}/bin/python ${root}/tools/strata_tokenizer.py --gguf ${gguf} --out $out
        '';
    };
    meta = {
      description = "Strata: GPU+RAM MoE inference server (OpenAI/Anthropic-compatible API)";
      homepage = "https://github.com/Niko1221/Strata";
      license = [lib.licenses.mit lib.licenses.unfreeRedistributable];
      platforms = ["x86_64-linux"];
      mainProgram = "strata-server";
    };
  } ''
    mkdir -p $out/bin $out/share
    ln -s ${root} $out/share/strata
    ln -s ${engine}/libexec $out/libexec
    cat > $out/bin/strata-server <<EOF
    #!${pkgs.runtimeShell}
    export PYTHONNOUSERSITE=1
    exec ${py}/bin/python ${root}/serve/server.py "\$@"
    EOF
    chmod +x $out/bin/strata-server
  ''
