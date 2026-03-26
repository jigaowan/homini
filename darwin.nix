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

  config = {
    assertions = lib.mapAttrsToList (
      name: userCfg:
      {
        assertion = !userCfg.homini.enable || userCfg.home != null;
        message = ''
          users.users."${name}".home must be set when users.users."${name}".homini.enable is true.
        '';
      }
    ) config.users.users;

    system.activationScripts = lib.mapAttrs' (
      name: userCfg:
      let
        home = toString userCfg.home;
        xdgConfigHome = "${home}/.config";
        xdgStateHome = "${home}/.local/state";
      in
      lib.nameValuePair "homini-${name}" {
        text = ''
          /usr/bin/sudo -u ${lib.escapeShellArg name} /usr/bin/env \
            HOME=${lib.escapeShellArg home} \
            XDG_CONFIG_HOME=${lib.escapeShellArg xdgConfigHome} \
            XDG_STATE_HOME=${lib.escapeShellArg xdgStateHome} \
            "${userCfg.homini.activationPackage}/bin/homini"
        '';
      }
    ) enabledUsers;
  };
}
