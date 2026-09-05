{
  flake.modules.homeManager.hyprland =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./hyprland/home.nix ];
      modules.home.hypr.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
