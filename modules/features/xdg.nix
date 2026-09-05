{
  flake.modules.homeManager.xdg =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./xdg/home.nix ];
      modules.home.xdg.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
