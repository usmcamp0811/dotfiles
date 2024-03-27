{ srob, ... }:

final: prev:

{
  srob-nvim = srob.packages.${prev.system}.default;
}

