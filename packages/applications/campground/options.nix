{pkgs, inputs, ...}: let
  self = inputs.self;
  moduleInputs = self.inputs // {inherit self;};
  snowfallLib = moduleInputs.snowfall-lib.mkLib {
    inputs = moduleInputs;
    src = self.outPath;
    snowfall = {
      namespace = "fmf";
      meta = {name = "fmf"; title = "AI Campground";};
    };
  };
  lib = snowfallLib.snowfall.internal.system-lib // {mdDoc = text: text;};
  evaluated = import "${moduleInputs.nixpkgs}/nixos/lib/eval-config.nix" {
    inherit lib pkgs;
    system = pkgs.stdenv.hostPlatform.system;
    specialArgs = {
      inherit lib;
      inputs = moduleInputs;
      system = pkgs.stdenv.hostPlatform.system;
      namespace = "fmf";
      host = "options-doc";
      format = "";
    };
    # The unfinished RMF example redeclares fmf.controls (owned by rmf) and
    # references an undefined cfg; it is not a standalone module schema.
    # Use source paths rather than Snowfall's exported wrappers, which inject
    # their own lib and would discard this documentation compatibility shim.
    modules = builtins.filter (path:
      baseNameOf path == "default.nix"
      && toString path != "${self.outPath}/modules/nixos/rmf/example-flask-app/default.nix"
    ) (lib.filesystem.listFilesRecursive (self.outPath + "/modules/nixos")) ++ [{
      # Schema-only evaluation: wrappers may configure external namespaces that
      # are deliberately not imported for this documentation-only system.
      _module.check = false;
      networking.hostName = "options-doc";
      system.stateVersion = "26.05";
    }];
  };
  docs = pkgs.nixosOptionsDoc {
    options = {inherit (evaluated.options) fmf;};
    warningsAreErrors = false;
    # Defaults in these modules can dereference Vault settings or host-specific
    # configuration. Do not evaluate them or invent a dummy host's values.
    transformOptions = option: (builtins.removeAttrs option ["default" "example"])
      // {declarations = map (path: lib.removePrefix "${self.outPath}/" (toString path)) option.declarations;};
  };
in pkgs.runCommand "campground-options" {
  nativeBuildInputs = [pkgs.fmf.okf pkgs.fmf.okf.python-env];
} ''
  python ${./options.py} ${docs.optionsJSON}/share/doc/nixos/options.json $out ${self.outPath}
  okf check $out/options
  okf index --write $out/options
''
