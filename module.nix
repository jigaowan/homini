{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config;
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
    };
in
{
  options = {
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
    activationPackage = import ./package.nix {
      inherit lib pkgs;
      file = cfg.file;
    };
  };
}
