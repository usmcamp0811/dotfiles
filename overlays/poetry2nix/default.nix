{ poetry2nix, ... }:

self: super: {

  # p2self & p2super refers to poetry2nix
  poetry2nix = super.poetry2nix.overrideScope' (p2nixself: p2nixsuper: {

    # pyself & pysuper refers to python packages
    defaultPoetryOverrides = p2nixsuper.defaultPoetryOverrides.extend (pyself: pysuper: {

      my-custom-pkg = super.my-custom-pkg.overridePythonAttrs (oldAttrs: { });

    });

  });
}

