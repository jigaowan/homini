{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homini;
  isRelativePath =
    value:
    value != ""
    && !lib.hasPrefix "/" value
    && !lib.hasInfix "\n" value
    && !lib.hasInfix "\t" value
    && !lib.any (segment: segment == "..") (lib.splitString "/" value);

  isRelativeTarget =
    value:
    isRelativePath value
    && !lib.hasSuffix "/" value;

  fileEntryModule =
    {
      name,
      config,
      ...
    }:
    {
      options = {
        source = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Relative path inside homini.dir for a managed file or directory.
          '';
        };

        text = lib.mkOption {
          type = lib.types.nullOr lib.types.lines;
          default = null;
          description = ''
            Text content to materialize in the Nix store and link into the target path.
          '';
        };
      };

      config.assertions = [
        {
          assertion = (config.source != null) != (config.text != null);
          message = ''
            homini.file.xdg_config."${name}" must set exactly one of source or text.
          '';
        }
        {
          assertion = isRelativeTarget name;
          message = ''
            homini.file.xdg_config."${name}" must be a relative path inside XDG_CONFIG_HOME.
          '';
        }
        {
          assertion = config.source == null || isRelativePath config.source;
          message = ''
            homini.file.xdg_config."${name}".source must be a relative path inside homini.dir.
          '';
        }
      ];
    };
in
{
  options.homini = {
    enable = lib.mkEnableOption ''Enable homini.'';

    dir = lib.mkOption {
      type = lib.types.path;
      description = ''
        The root directory used to resolve homini.file.*.source paths.
      '';
    };

    file = lib.mkOption {
      default = { };
      description = ''
        Declarative file entries managed by homini.
      '';
      type = lib.types.submodule {
        options.xdg_config = lib.mkOption {
          default = { };
          description = ''
            Entries linked into $XDG_CONFIG_HOME or $HOME/.config.
          '';
          type = lib.types.attrsOf (lib.types.submodule fileEntryModule);
        };
      };
    };

    activationPackage = lib.mkOption {
      internal = true;
      type = lib.types.package;
      description = ''
        The package containing the complete activation script.
      '';
    };
  };

  config = {
    homini.activationPackage = import ./package.nix {
      inherit lib pkgs;
      dir = cfg.dir;
      file = cfg.file;
    };
  };
}
