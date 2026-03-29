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

  config = {
    assertions = lib.mapAttrsToList (
      name: userCfg:
      {
        assertion = userCfg.homini == null || userCfg.home != null;
        message = ''
          users.users."${name}".home must be set when users.users."${name}".homini is configured.
        '';
      }
    ) config.users.users;

    system.activationScripts.postActivation.text = lib.mkAfter (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: userCfg:
          let
            home = toString userCfg.home;
            xdgConfigHome = "${home}/.config";
            xdgStateHome = "${home}/.local/state";
          in
          ''
            /usr/bin/sudo -u ${lib.escapeShellArg name} /usr/bin/env \
              HOME=${lib.escapeShellArg home} \
              XDG_CONFIG_HOME=${lib.escapeShellArg xdgConfigHome} \
              XDG_STATE_HOME=${lib.escapeShellArg xdgStateHome} \
              "${userCfg.homini.activationPackage}/bin/homini"
          ''
        ) enabledUsers
      )
    );
  };
}
