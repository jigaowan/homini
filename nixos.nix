{ config, lib, pkgs, ... }:

let
  hominiUserModule = import ./module.nix;
  hominiUserType = lib.types.submoduleWith {
    modules = [ hominiUserModule ];
    specialArgs = { inherit pkgs; };
    shorthandOnlyDefinesConfig = true;
  };
  enabledUsers = lib.filterAttrs (_: userCfg: userCfg.homini.enable or false) config.users.users;
in
{
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf hominiUserType;
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
