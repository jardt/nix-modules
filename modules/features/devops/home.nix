{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.home.devops;
  enableLimaOnMacOS = cfg.enableLima && pkgs.stdenv.hostPlatform.isDarwin;
  enableColimaOnMacOS = cfg.enableColima && pkgs.stdenv.hostPlatform.isDarwin;
in
{

  options.modules.home.devops = {
    kliPackage = mkOption {
      type = types.package;
      description = "Kli package to install with the Kubernetes tools.";
    };

    enableDocker = mkEnableOption "enable docker and related";
    enableK8sTools = mkEnableOption "enable k8s tools";
    enableLima = mkEnableOption "enable lima for macos";
    enableColima = mkEnableOption "enable colima for macos";
  };
  config = {

    home.packages =
      with pkgs;
      (
        if cfg.enableDocker then
          [
            docker
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ podman ]
        else
          [ ]
      )
      ++ (
        if cfg.enableK8sTools then
          [
            kubectl
            fluxcd
            kustomize
            cilium-cli
            kubefetch
            kubeseal
            talosctl
            cfg.kliPackage
          ]
        else
          [ ]
      )
      ++ (
        if enableLimaOnMacOS then
          [
            lima-additional-guestagents
            lima
          ]
        else
          [ ]
      )
      ++ (
        if enableColimaOnMacOS then
          [
            colima
          ]
        else
          [ ]
      );

    programs.lazydocker = {
      enable = cfg.enableDocker;
    };

    services.colima = mkIf enableColimaOnMacOS {
      enable = true;
    };

    programs.k9s = {
      enable = cfg.enableK8sTools;
      settings = {
        skin = "skin";
      };
    };

    programs.kubecolor = {
      enable = cfg.enableK8sTools;
      enableZshIntegration = true;
    };

    programs.zsh.initContent =
      ""
      + (
        if cfg.enableK8sTools then
          ''
            source <(kubectl completion zsh)
            source <(flux completion zsh)
            source <(kustomize completion zsh)

          ''
        else
          ""
      )
      + (
        if enableLimaOnMacOS then
          ''
            source <(limactl completion zsh)
          ''
        else
          ""
      )
      + (
        if enableColimaOnMacOS then
          ''
            source <(colima completion zsh)
          ''
        else
          ""
      );

    home.shellAliases = {
      k = mkIf cfg.enableK8sTools "kubectl";
      limakube = mkIf enableLimaOnMacOS ''export KUBECONFIG="${config.home.homeDirectory}/.lima/k8s/copied-from-guest/kubeconfig.yaml"'';
      limassh = mkIf enableLimaOnMacOS "ssh -F ~/.lima/default/ssh.config lima-default";
      ld = mkIf cfg.enableDocker "lazydocker";
    };
  };

}
