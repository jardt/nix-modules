{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.home.zsh;
  televisionEnabled = attrByPath [ "modules" "home" "television" "enable" ] false config;
  lsWithColor = if pkgs.stdenv.hostPlatform.isDarwin then "ls -G" else "ls --color";
in
{

  options.modules.home.zsh = {
    enable = mkOption {
      type = types.bool;
      default = true;
      example = true;
      description = "enable zsh";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        bat
        fd
        neovim
        fzf
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        wl-clipboard
      ];

    home.sessionPath = [
      "$HOME/.local/scripts"
      "$HOME/.local/bin"
    ];

    home.file.".local/scripts/fzf-cd" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash

        selected=$(fd . ~ -t d -d 3 -H -E Applications -E Library -E Music -E Movies -E Pictures -E Downloads -E Desktop -E Documents | fzf)

        if [[ $selected ]]; then
          cd "$selected"
        fi
      '';
    };

    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";

      history = {
        expireDuplicatesFirst = true;
        share = true;
        size = 10000;
      };

      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      historySubstringSearch.enable = true;

      initContent = lib.mkMerge [
        # zsh-vi-mode reads zvm_config when Home Manager sources the plugin at
        # order 560, so all of its callbacks must already be defined.
        (lib.mkOrder 550 ''
          function zvm_config() {
            ZVM_CURSOR_STYLE_ENABLED=false
          }

          function zvm_custom_keybindings() {
            zvm_bindkey viins '^Y' autosuggest-accept
            ${lib.optionalString televisionEnabled "zvm_bindkey viins '^R' tv-shell-history"}
            ${lib.optionalString televisionEnabled "zvm_bindkey vicmd '^R' tv-shell-history"}
            ${lib.optionalString (!televisionEnabled) "zvm_bindkey viins '^R' fzf-history-widget"}
            ${lib.optionalString (!televisionEnabled) "zvm_bindkey vicmd '^R' fzf-history-widget"}
          }

          function zvm_vi_yank() {
            zvm_yank
            if (( $+functions[zsh-system-clipboard-set] )); then
              print -rn -- "''${CUTBUFFER}" | zsh-system-clipboard-set
            fi
            zvm_exit_visual_mode
          }

          function zvm_after_init() {
            zvm_custom_keybindings
          }

          function zvm_after_lazy_keybindings() {
            zvm_custom_keybindings
          }
        '')
        # Herdr forwards OSC 52 writes from pane applications to the attached
        # client's clipboard, including when its server is headless. Outside
        # Herdr, initialize only a clipboard backend available in this session.
        (lib.mkOrder 565 ''
          if [[ "''${HERDR_ENV:-}" == 1 ]]; then
            function zsh-system-clipboard-set() {
              local encoded
              encoded="$(${pkgs.coreutils}/bin/base64 | ${pkgs.coreutils}/bin/tr -d '\n')" || return
              printf '\e]52;c;%s\a' "$encoded"
            }
          elif [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
            ZSH_SYSTEM_CLIPBOARD_USE_WL_CLIPBOARD=1
            source ${pkgs.zsh-system-clipboard}/share/zsh/zsh-system-clipboard/zsh-system-clipboard.zsh
          elif [[ "''${OSTYPE:-}" == darwin* ]]; then
            source ${pkgs.zsh-system-clipboard}/share/zsh/zsh-system-clipboard/zsh-system-clipboard.zsh
          elif [[ -n "''${DISPLAY:-}" ]] && (( $+commands[xclip] || $+commands[xsel] )); then
            source ${pkgs.zsh-system-clipboard}/share/zsh/zsh-system-clipboard/zsh-system-clipboard.zsh
          fi
        '')
        ''
          ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
          ZSH_AUTOSUGGEST_USE_ASYNC=1

          ${lib.optionalString televisionEnabled ''
            eval "$(tv init zsh)"
          ''}
          bindkey -M vicmd 'k' history-substring-search-up
          bindkey -M vicmd 'j' history-substring-search-down
          bindkey '^Y' autosuggest-accept
          bindkey -s ^o ". fzf-cd .\n"

          zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
          zstyle ':completion:*' menu no
          zstyle ':fzf-tab:complete:cd:*' fzf-preview '${lsWithColor} "$realpath"'

          path+=($HOME/.npm/bin)
          ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=3'
        ''
      ];

      plugins = [
        {
          name = "vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
        {
          name = "zsh-fzf-tab";
          src = pkgs.zsh-fzf-tab;
          file = "share/fzf-tab/fzf-tab.plugin.zsh";
        }
      ];
    };

    programs.bash.enable = true;

    home.sessionVariables = {
      EDITOR = mkDefault "nvim";
      VISUAL = mkDefault "nvim";
    };

    home.shellAliases = {
      ls = lsWithColor;
      f = ''$EDITOR $(fzf --preview="bat --color=always {}")'';
    };
  };
}
