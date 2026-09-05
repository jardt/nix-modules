{
  flake.modules.homeManager.media =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./media/home.nix ];
      modules.home.media.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
