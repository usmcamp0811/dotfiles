{ channels, gbar, ... }:

final: prev:

{
  inherit (gbar.packages.${final.system}) gbar;
}
