{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homini;
  normalizeSource =
    value:
    if builtins.isPath value then
      toString value
    else
      value;

  isSinglePathValue =
    value:
    value != ""
    && !lib.hasInfix "\n" value
    && !lib.hasInfix "\t" value;

  isAbsolutePath =
    value:
    lib.hasPrefix "/" value;

  isRelativePath =
    value:
    isSinglePathValue value
    && !lib.hasPrefix "/" value
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
          type = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);
          default = null;
          description = ''
            Relative path inside the target user's home directory, or an absolute path
            to a managed file or directory.
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
          assertion =
            config.source == null
            || (
              let
                source = normalizeSource config.source;
              in
              isSinglePathValue source && (isAbsolutePath source || isRelativePath source)
            );
          message = ''
            homini.file.xdg_config."${name}".source must be an absolute path or a relative
            path inside the target user's home directory.
          '';
        }
      ];
    };
in
{
  options.homini = {
    enable = lib.mkEnableOption ''Enable homini for this user.'';

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

  config = lib.mkIf cfg.enable {
    homini.activationPackage = import ./package.nix {
      inherit lib pkgs;
      file = cfg.file;
    };
  };
}
