{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs) lib;

      # Evaluate broad module combinations instead of constructing a complete
      # configuration for every export. The coverage assertion below
      # requires each public module to remain assigned to a composition.
      homeCompositions = {
        workstation = [
          "ai"
          "bat"
          "btop"
          "bun"
          "cli-tools"
          "default"
          "devops"
          "direnv"
          "dstask"
          "eza"
          "fzf"
          "git"
          "gondolin"
          "herdr"
          "jujutsu"
          "neovim"
          "nh"
          "node"
          "presentation"
          "reverse-engineering"
          "starship"
          "taskwarrior"
          "television"
          "tmux"
          "yazi"
          "zsh"
        ];

        graphical = [
          "aerospace"
          "bitwarden"
          "dwm"
          "firefox"
          "fonts"
          "fsel"
          "ghostty"
          "hyprland"
          "i3"
          "kitty"
          "mango"
          "media"
          "screenshot"
          "stylix"
          "sway"
          "vscode"
          "waybar"
          "xdg"
          "zathura"
        ];
      };

      nixosCompositions = {
        laptop-kanata = [
          "base-packages"
          "bluetooth"
          "fonts"
          "kanata"
          "laptop-base"
          "mango"
          "oryx"
          "stylix"
          "wifi"
        ];

        laptop-keyd = [
          "base-packages"
          "fonts"
          "keyd"
          "laptop-base"
          "stylix"
        ];

        server = [
          "base-packages"
          "disk-monitor"
          "home-assistant"
          "stylix"
        ];
      };

      requireCompleteCoverage =
        kind: exports: compositions:
        let
          exportedNames = builtins.attrNames exports;
          coveredNames = lib.unique (lib.concatLists (builtins.attrValues compositions));
          missing = lib.filter (name: !(builtins.elem name coveredNames)) exportedNames;
          unknown = lib.filter (name: !(builtins.hasAttr name exports)) coveredNames;
        in
        if missing == [ ] && unknown == [ ] then
          compositions
        else
          throw ''
            ${kind} composition coverage is incomplete.
            Missing exports: ${lib.concatStringsSep ", " missing}
            Unknown exports: ${lib.concatStringsSep ", " unknown}
          '';

      checkedHomeCompositions = requireCompleteCoverage "Home Manager" self.homeModules homeCompositions;
      checkedNixosCompositions = requireCompleteCoverage "NixOS" self.nixosModules nixosCompositions;

      modulesFor = exports: names: map (name: exports.${name}) names;

      mkEvaluationCheck =
        name: context: drvPath:
        let
          evaluated = builtins.addErrorContext "while evaluating ${context}: " drvPath;
        in
        builtins.seq evaluated (pkgs.runCommand "check-${name}" { } "touch $out");

      mkHomeCheck =
        name: moduleNames:
        let
          includesStylix = builtins.elem "stylix" moduleNames;
          configuration = inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = modulesFor self.homeModules moduleNames ++ [
              (
                {
                  # Match consumers that share their system package set with Home
                  # Manager. Stylix's package overlay is covered by its NixOS
                  # composition instead of rebuilding pkgs inside this check.
                  _module.args.pkgs = lib.mkForce pkgs;

                  home = {
                    username = "module-test";
                    homeDirectory =
                      if pkgs.stdenv.hostPlatform.isDarwin then "/Users/module-test" else "/home/module-test";
                    stateVersion = "26.05";
                  };
                }
                // lib.optionalAttrs includesStylix { stylix.overlays.enable = false; }
              )
            ];
          };
        in
        mkEvaluationCheck "home-composition-${name}" "Home Manager composition '${name}'"
          configuration.activationPackage.drvPath;

      mkNixosCheck =
        name: moduleNames:
        let
          configuration = inputs.nixpkgs.lib.nixosSystem {
            modules = modulesFor self.nixosModules moduleNames ++ [
              {
                nixpkgs.pkgs = pkgs;
                system.stateVersion = "26.05";

                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "/dev/disk/by-label/nixos";
                  fsType = "ext4";
                };
              }
            ];
          };
        in
        mkEvaluationCheck "nixos-composition-${name}" "NixOS composition '${name}'"
          configuration.config.system.build.toplevel.drvPath;
    in
    {
      checks =
        lib.mapAttrs' (
          name: modules: lib.nameValuePair "home-${name}" (mkHomeCheck name modules)
        ) checkedHomeCompositions
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
          lib.mapAttrs' (
            name: modules: lib.nameValuePair "nixos-${name}" (mkNixosCheck name modules)
          ) checkedNixosCompositions
        );
    };
}
