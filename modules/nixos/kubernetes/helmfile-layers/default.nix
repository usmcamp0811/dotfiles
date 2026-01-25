{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.k3s.helmfile.layers;

  yamlFormat = pkgs.formats.yaml {};

  # Generate a helmfile for a specific layer
  mkLayerHelmfile = layerCfg: let
    releases = map (release: {
      name = release.name;
      namespace = release.namespace;
      chart = release.chart;
      createNamespace = release.createNamespace or true;
      wait = release.wait or true;
      timeout = release.timeout or 600;
    }
    // lib.optionalAttrs (release ? needs && release.needs != []) {needs = release.needs;}
    // lib.optionalAttrs (release ? values && release.values != []) {values = release.values;}
    // lib.optionalAttrs (release ? set && release.set != []) {set = release.set;}
    // lib.optionalAttrs (release ? hooks && release.hooks != []) {hooks = release.hooks;}
    // lib.optionalAttrs (release ? atomic) {atomic = release.atomic;}
    ) layerCfg.releases;
  in yamlFormat.generate "helmfile-${layerCfg.name}.yaml" ({
    repositories = layerCfg.repositories or [];

    helmDefaults = {
      wait = true;
      timeout = 600;
      atomic = true;
      recreatePods = false;
      force = false;
    };

    releases = releases;
  } // lib.optionalAttrs (layerCfg ? hooks && layerCfg.hooks != []) {
    hooks = layerCfg.hooks;
  });

  # Root helmfile that includes all layers
  rootHelmfile = let
    enabledLayers = filter (l: l.enable) (attrValues cfg.layerConfigs);
    sortedLayers = sort (a: b: a.order < b.order) enabledLayers;

    helmfiles = map (layer: {
      path = "layers/${layer.name}/helmfile.yaml";
    } // lib.optionalAttrs (layer.needs != []) {
      needs = map (n: "layers/${n}/helmfile.yaml") layer.needs;
    }) sortedLayers;
  in yamlFormat.generate "helmfile-root.yaml" {
    helmDefaults = {
      wait = true;
      timeout = 600;
      atomic = true;
    };

    inherit helmfiles;
  };

  # Generate all layer files
  layerFiles = listToAttrs (map (layer:
    nameValuePair "layers/${layer.name}/helmfile.yaml" {
      source = mkLayerHelmfile layer;
    }
  ) (filter (l: l.enable) (attrValues cfg.layerConfigs)));
in {
  options.fmf.services.k3s.helmfile.layers = {
    enable = mkEnableOption "Use layered helmfile architecture";

    rootDir = mkOption {
      type = types.path;
      default = "/etc/helmfile";
      description = "Root directory for helmfile configuration";
    };

    layerConfigs = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "Enable this layer" // {default = true;};

          name = mkOption {
            type = types.str;
            default = name;
            description = "Layer name";
          };

          order = mkOption {
            type = types.int;
            description = "Layer order (lower numbers deploy first)";
          };

          needs = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of layer names this layer depends on";
          };

          repositories = mkOption {
            type = types.listOf types.attrs;
            default = [];
            description = "Helm repositories needed for this layer";
          };

          releases = mkOption {
            type = types.listOf types.attrs;
            default = [];
            description = "Helm releases in this layer";
          };

          hooks = mkOption {
            type = types.listOf types.attrs;
            default = [];
            description = "Helmfile environment hooks for this layer";
          };
        };
      }));
      default = {};
      description = "Layer configurations";
    };
  };

  config = mkIf cfg.enable {
    # Generate helmfile directory structure
    environment.etc = {
      "helmfile/helmfile.yaml".source = rootHelmfile;
    } // layerFiles;
  };
}
