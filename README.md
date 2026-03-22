# Homini

Homini is a **minimalist dotfiles manager** using Nix inspired by
[Home Manager](https://github.com/nix-community/home-manager) and
[GNU Stow](https://www.gnu.org/software/stow/).

## How to use Homini?

Consider the following snippet

```nix
homini = {
  enable = true;
  dir = ./dotfiles;

  file.xdg_config."git".source = ".config/git";
  file.xdg_config."keyd".source = ".config/keyd";
  file.xdg_config."zed/settings.json".text = ''
    {
      "theme": "Ayu Dark"
    }
  '';
};
```

This will link explicit entries from `dotfiles` into `$XDG_CONFIG_HOME`
or `$HOME/.config`.

```
dotfiles
└── .config
    ├── git
    │   ├── config
    │   ├── ignore
    │   ├── personal
    │   └── work
    └── keyd
        └── default.conf
```

The resulting managed paths look like this:

```
$XDG_CONFIG_HOME
├── git -> /nix/store/...-dotfiles/.config/git
├── keyd -> /nix/store/...-dotfiles/.config/keyd
└── zed
    ├── settings.json -> /nix/store/...-homini-zed-settings.json
    └── history.json
```

`history.json` is left untouched because Homini only manages the paths you
declare.

### NixOS

Rebuild the following flake with `nixos-rebuild switch --flake .#machine`.

```nix
{
  description = "My NixOS Configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    homini.url = "github:smoothprogrammer/homini";
    homini.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, homini, ... }: {
    nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        homini.nixosModules.homini {
          homini = {
            enable = true;
            dir = ./dotfiles;
            file.xdg_config."git".source = ".config/git";
            file.xdg_config."zed/settings.json".text = ''
              {
                "theme": "Ayu Dark"
              }
            '';
          };
        }
      ];
    };
  };
}
```

### MacOS (nix-darwin)

Rebuild the following flake with `darwin-rebuild switch --flake .#machine`.

```nix
{
  description = "My MacOS (nix-darwin) Configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    homini.url = "github:smoothprogrammer/homini";
    homini.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { darwin, homini, ... }: {
    darwinConfigurations.machine = darwin.lib.darwinSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        homini.darwinModules.homini {
          homini = {
            enable = true;
            dir = ./dotfiles;
            file.xdg_config."git".source = ".config/git";
          };
        }
      ];
    };
  };
}
```

### Standalone

Run the following flake with `nix run`.

```nix
{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    homini.url = "github:smoothprogrammer/homini";
    homini.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, homini, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (system: {
        default = homini.standalone {
          pkgs = nixpkgs.legacyPackages.${system};
          dir = ./dotfiles;
          file.xdg_config."git".source = ".config/git";
        };
      });
    };
}
```

## Why Homini when we have Home Manager?

This [Article](https://www.fbrs.io/nix-hm-reflections) by [Florian Beeres](https://github.com/cideM/)
is what inspired me to write Homini and this quote sums up why

> At the end of the day I really don’t need the per-user installation of packages
> and elaborate modules that Home Manager gives me.
> I’d be perfectly content with providing a list of packages to install system-wide
> and a few basic primitives to generate configuration files in my home folder.
