{
  flake.modules.homeManager.screenshot =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./screenshot/home.nix ];
      modules.home.screenshot.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
