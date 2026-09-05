{
  flake.modules.homeManager.ghostty =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./ghostty/home.nix ];
      modules.home.ghostty.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
