{
  pkgs,
  dir,
  file ? { },
}:

import ./package.nix {
  inherit dir file pkgs;
  lib = pkgs.lib;
}
