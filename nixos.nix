{ config, lib, pkgs, ... }:

let
  hominiConfigModule = import ./module.nix;
  hominiConfigType = lib.types.submoduleWith {
    modules = [ hominiConfigModule ];
    specialArgs = { inherit pkgs; };
    shorthandOnlyDefinesConfig = true;
  };
  hominiUserType = lib.types.submoduleWith {
    modules = [
      {
        options.homini = lib.mkOption {
          type = lib.types.nullOr hominiConfigType;
          default = null;
          description = ''
            Homini configuration for this user.
          '';
        };
      }
    ];
    shorthandOnlyDefinesConfig = true;
  };
  enabledUsers = lib.filterAttrs (_: userCfg: userCfg.homini != null) config.users.users;
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
