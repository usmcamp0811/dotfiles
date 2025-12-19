{ lib
, writeText
, writeShellApplication
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.fmf) override-meta;

  resume-json = ../../websites/matt-camp-website/src/assets/resume/resume.json;
  resume-latex = pkgs.stdenv.mkDerivation {
    name = "resume-latex";
    src = ./.;
    installPhase = ''
      mkdir -p $out
      cp $src/resume.cls $out/resume.cls
      cp $src/resume.jinja $out/resume.jinja
    '';
  };

  make-resume = pkgs.writeShellScriptBin "make-resume" ''
    current_dir=$(pwd)
    # Create a temporary directory.
    temp_dir=$(mktemp -d)
    json_path=''${1:-"${resume-json}"}

    ${pkgs.jinja2-cli}/bin/jinja2 ${resume-latex}/resume.jinja $json_path > ''${temp_dir}/resume.tex
    cp ${resume-latex}/resume.cls ''${temp_dir}/
    cd $temp_dir
    ${pkgs.texlive.combined.scheme-full}/bin/pdflatex ''${temp_dir}/resume.tex
    ${pkgs.texlive.combined.scheme-full}/bin/pdflatex ''${temp_dir}/resume.tex
    cp ''${temp_dir}/resume.pdf $current_dir/resume.pdf
  '';

  resume-builder = pkgs.stdenv.mkDerivation {
    name = "resume-builder";
    src = ./.;
    propagatedBuildInputs = [ pkgs.texliveTeTeX pkgs.texliveFull ];
    installPhase = ''
      mkdir -p $out/bin
      cp ${make-resume}/bin/make-resume $out/bin/make-resume
    '';
  };
  new-meta = with lib; {
    description = "A package to compile my resume into a PDF";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
    mainProgram = "make-resume";
  };
in
override-meta new-meta resume-builder
