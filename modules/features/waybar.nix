{
  flake.modules.homeManager.waybar =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./waybar/home.nix ];
      modules.home.waybar.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
