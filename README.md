# ❄️ nix-modules

Reusable NixOS and Home Manager modules, packages, and development tooling.

This repository is the public module layer. It contains shared defaults,
application modules, desktop wiring, packages, and small utilities. Host
composition, secrets, private network layout, users, SSH keys, and
machine-specific state belong in the consuming configuration repository.

## Outputs

### Home Manager modules

Home Manager modules are exported under `homeModules` and
`modules.homeManager`:

- `aerospace`
- `ai`
- `bat`
- `bitwarden`
- `btop`
- `bun`
- `cli-tools`
- `default`
- `devops`
- `direnv`
- `dstask`
- `dwm`
- `eza`
- `firefox`
- `fonts`
- `fsel`
- `fzf`
- `ghostty`
- `git`
- `gondolin`
- `herdr`
- `hyprland`
- `i3`
- `jujutsu`
- `kitty`
- `mango`
- `media`
- `neovim`
- `nh`
- `node`
- `presentation`
- `reverse-engineering`
- `screenshot`
- `starship`
- `stylix`
- `sway`
- `taskwarrior`
- `television`
- `tmux`
- `vscode`
- `waybar`
- `xdg`
- `yazi`
- `zathura`
- `zsh`

### NixOS modules

NixOS modules are exported under `nixosModules` and `modules.nixos`:

- `base-packages`
- `bluetooth`
- `disk-monitor`
- `fonts`
- `home-assistant`
- `kanata`
- `keyd`
- `laptop-base`
- `mango`
- `oryx`
- `stylix`
- `wifi`

### Packages

Packages are exported under `packages.${system}`:

- `cclip` (Linux only)
- `chdman`
- `codex`
- `firecrawl-cli`
- `gondolin`
- `hbcdump`
- `hunk`
- `kli`
- `mango` (Linux only)
- `ntn`
- `playwright-cli`
- `stack`

Build a package directly:

```sh
nix build .#cclip
```

Or consume one from another flake:

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.nix-modules.packages.${pkgs.stdenv.hostPlatform.system}.gondolin
  ];
}
```

### Utilities

- `utils/fix-nix-daemon-ca.sh`

## Use from another flake

Add the repository as an input:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nix-modules.url = "github:USER/nix-modules";
  };
}
```

For unpublished local development, use a path input:

```nix
nix-modules.url = "path:/path/to/nix-modules";
```

## Import individual modules

### Module activation

Importing a public leaf module enables its primary behavior by default on
supported platforms. Consumers can still disable it explicitly or conditionally;
ordinary definitions override
the module's `lib.mkDefault` activation:

```nix
{
  imports = [ inputs.nix-modules.homeModules.television ];
  modules.home.television.enable = isDesktop;
}
```

Optional subfeatures remain opt-in. Collection and support modules without one
primary behavior also expose explicit capability switches. Wrapped Neovim is
consumed directly from its own flake rather than through this repository.

Disk monitoring is also opt-in. Import `nixosModules.disk-monitor`, set
`modules.nixos.disk-monitor.enable = true`, and supply
`modules.nixos.disk-monitor.ntfyUrl` with your notification topic URL.
There is no default URL to avoid sending alerts to an unrelated endpoint.

Importing `flakeModules.default` only registers the public module collections and
packages in a flake-parts consumer; it does not activate every Home Manager or
NixOS module in a host configuration.

### NixOS

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nix-modules.nixosModules.base-packages
    inputs.nix-modules.nixosModules.bluetooth
    inputs.nix-modules.nixosModules.fonts
  ];
}
```

### Home Manager

```nix
{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nix-modules.homeModules.default
    inputs.nix-modules.homeModules.git
    inputs.nix-modules.homeModules.firefox
    inputs.nix-modules.homeModules.reverse-engineering
    inputs.nix-modules.homeModules.zsh
  ];

  modules.home.firefox.profile = "default";

  # The imported parent feature is active; optional tool groups remain opt-in.
  modules.home.reverse-engineering = {
    android.enable = true;
    extraPackages = [ pkgs.ghidra ];
  };
}
```

## Import the complete flake-parts module

A consumer using flake-parts can import the complete feature collection:

```nix
{ inputs, ... }:
{
  imports = [ inputs.nix-modules.flakeModules.default ];
}
```

The exported flake module captures its owning flake, so it works regardless of
the consumer-side input name. It contributes class-aware collections under
`flake.modules.homeManager` and `flake.modules.nixos`, while preserving the
established `homeModules`, `nixosModules`, and package outputs.

Directly importing `"${inputs.nix-modules}/modules"` remains supported for
compatibility.
