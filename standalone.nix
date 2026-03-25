{
  pkgs,
  file ? { },
}:

import ./package.nix {
  inherit file pkgs;
  lib = pkgs.lib;
}
