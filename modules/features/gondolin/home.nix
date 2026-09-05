{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.home.gondolin;

  gondolinArch = if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64";

  ociPlatform = if pkgs.stdenv.hostPlatform.isAarch64 then "linux/arm64" else "linux/amd64";

  nixImageConfig = pkgs.writeText "gondolin-nix-image.json" (
    builtins.toJSON {
      arch = gondolinArch;
      distro = "alpine";
      oci = {
        image = cfg.nixImage.ociImage;
        platform = ociPlatform;
        pullPolicy = "if-not-present";
      };
      rootfs.label = "gondolin-nix";
      env.NIX_CONFIG = "experimental-features = nix-command flakes";
      postBuild.commands = [
        "mkdir -p /etc/nix /root/.config/nix"
        "printf '%s\\n' 'experimental-features = nix-command flakes' > /etc/nix/nix.conf"
        "printf '%s\\n' 'experimental-features = nix-command flakes' > /root/.config/nix/nix.conf"
        "nix profile install --profile /nix/var/nix/profiles/default nixpkgs#bashInteractive nixpkgs#bat nixpkgs#coreutils nixpkgs#curl nixpkgs#delta nixpkgs#diffutils nixpkgs#fd nixpkgs#findutils nixpkgs#fzf nixpkgs#gawk nixpkgs#git nixpkgs#gnugrep nixpkgs#gnused nixpkgs#jq nixpkgs#less nixpkgs#procps nixpkgs#ripgrep nixpkgs#tree nixpkgs#unzip nixpkgs#vim nixpkgs#wget nixpkgs#xz nixpkgs#zip github:numtide/llm-agents.nix#pi"
      ];
    }
  );

  gondolinNixBuildImage = pkgs.writeShellApplication {
    name = "gondolin-nix-build-image";
    runtimeInputs = [ cfg.package ];
    text = ''
      set -euo pipefail
      output="''${1:-$HOME/.cache/gondolin/nix-assets}"
      mkdir -p "$(dirname "$output")"
      gondolin build --config ${nixImageConfig} --output "$output"
      echo "$output"
    '';
  };

  gondolinNixDevelop = pkgs.writeShellApplication {
    name = "gondolin-nix-develop";
    runtimeInputs = [ cfg.package ] ++ optional cfg.binaryCache.enable pkgs.nix-serve;
    text = ''
      set -euo pipefail
      image="''${GONDOLIN_NIX_IMAGE:-$HOME/.cache/gondolin/nix-assets}"
      if [ ! -e "$image/manifest.json" ]; then
        echo "Missing Gondolin Nix image at $image" >&2
        echo "Run: gondolin-nix-build-image" >&2
        exit 1
      fi

      gondolin_args=(
        --image "$image"
        --rootfs-size ${cfg.nixImage.rootfsSize}
        --mount-hostfs "$PWD:/workspace"
        --cwd /workspace
        --allow-host cache.nixos.org
        --allow-host github.com
        --allow-host "*.github.com"
        --allow-host "*.githubusercontent.com"
      )

      ${optionalString cfg.piConfig.mount ''
        pi_config="''${GONDOLIN_PI_CONFIG_DIR:-${cfg.piConfig.hostPath}}"
        if [ -d "$pi_config" ]; then
          gondolin_args+=(--mount-hostfs "$pi_config:${cfg.piConfig.guestPath}${optionalString cfg.piConfig.readOnly ":ro"}")
        else
          echo "warning: Pi config dir not found: $pi_config" >&2
        fi
      ''}

      nix_args=(
        --extra-experimental-features 'nix-command flakes'
      )

      ${optionalString cfg.binaryCache.enable ''
        cache_port="''${GONDOLIN_NIX_CACHE_PORT:-${toString cfg.binaryCache.port}}"
        cache_host="${cfg.binaryCache.guestHost}"

        nix-serve --listen 127.0.0.1:"$cache_port" &
        cache_pid="$!"
        trap 'kill "$cache_pid" 2>/dev/null || true' EXIT

        gondolin_args+=(--tcp-map "$cache_host:$cache_port=127.0.0.1:$cache_port")
        nix_args+=(
          --option substituters "http://$cache_host:$cache_port https://cache.nixos.org/"
          --option require-sigs false
        )
      ''}

      exec gondolin bash "''${gondolin_args[@]}" -- nix "''${nix_args[@]}" develop "$@"
    '';
  };
in
{
  options.modules.home.gondolin = {
    enable = mkEnableOption "Gondolin sandbox CLI";

    package = mkOption {
      type = types.package;
      description = "Gondolin package to install.";
    };

    enableQemu = mkOption {
      type = types.bool;
      default = pkgs.stdenv.hostPlatform.isLinux;
      defaultText = literalExpression "pkgs.stdenv.hostPlatform.isLinux";
      example = false;
      description = "Install QEMU alongside Gondolin for the default qemu backend on Linux.";
    };

    binaryCache = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Start a host nix-serve binary cache and expose it to the Gondolin VM during gondolin-nix-develop.";
      };

      port = mkOption {
        type = types.port;
        default = 5005;
        description = "Localhost port used for the temporary host Nix binary cache.";
      };

      guestHost = mkOption {
        type = types.str;
        default = "nix-cache.internal";
        description = "Synthetic hostname used by the guest to reach the host Nix binary cache.";
      };
    };

    piConfig = {
      mount = mkOption {
        type = types.bool;
        default = true;
        description = "Mount the host Pi config directory into the Gondolin VM so pi keeps authentication and local setup.";
      };

      hostPath = mkOption {
        type = types.str;
        default = "$HOME/.pi";
        description = "Host Pi config directory mounted into the VM. Can be overridden at runtime with GONDOLIN_PI_CONFIG_DIR.";
      };

      guestPath = mkOption {
        type = types.str;
        default = "/root/.pi";
        description = "Guest path where the Pi config directory is mounted.";
      };

      readOnly = mkOption {
        type = types.bool;
        default = false;
        description = "Mount the Pi config directory read-only. Defaults to writable so Pi can update session/auth state.";
      };
    };

    nixImage = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install helper scripts for building and entering a Nix-enabled Gondolin VM.";
      };

      ociImage = mkOption {
        type = types.str;
        default = "docker.io/nixos/nix:latest";
        description = "OCI rootfs image used to build the Nix-enabled Gondolin guest image.";
      };

      rootfsSize = mkOption {
        type = types.str;
        default = "8G";
        example = "20G";
        description = "Root filesystem size passed to Gondolin when starting the Nix VM.";
      };
    };
  };

  config = mkIf cfg.enable {
    warnings = optional pkgs.stdenv.hostPlatform.isDarwin ''
      modules.home.gondolin: QEMU is not installed by this Home Manager module on macOS.
      Install it separately, for example with Homebrew (`brew install qemu`) or a nix-darwin Homebrew module.
    '';

    home.packages = [
      cfg.package
    ]
    ++ optional (cfg.enableQemu && pkgs.stdenv.hostPlatform.isLinux) pkgs.qemu
    ++ optionals cfg.nixImage.enable [
      gondolinNixBuildImage
      gondolinNixDevelop
    ];

    xdg.configFile = mkIf cfg.nixImage.enable {
      "gondolin/nix-image.json".source = nixImageConfig;
    };
  };
}
