{ config, lib, ... }:

let
  hominiUserModule = import ./module.nix;
  enabledUsers = lib.filterAttrs (_: userCfg: userCfg.homini.enable or false) config.users.users;
in
{
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule [ hominiUserModule ]);
  };

  config.system.userActivationScripts = lib.mapAttrs' (
    name: userCfg:
    lib.nameValuePair "homini-${name}" {
      text = ''
        if [[ "$USER" == ${lib.escapeShellArg name} ]]; then
          "${userCfg.homini.activationPackage}/bin/homini"
        fi
      '';
    }
  ) enabledUsers;
}
