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
in
  pkgs.runCommand "strata-${version}" {
    inherit version;
    passthru = {
      inherit engine root py llamaCpp src rev cudaArchitectures;
      # exe of the engine, as the run config's "exe" wants it
      enginePath = "${engine}/libexec/strata/strata";
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
