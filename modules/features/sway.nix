{
  flake.modules.homeManager.sway =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./sway/home.nix ];
      modules.home.sway.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
