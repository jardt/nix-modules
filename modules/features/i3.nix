{
  flake.modules.homeManager.i3 =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./i3/home.nix ];
      modules.home.i3.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
