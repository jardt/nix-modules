{
  flake.modules.homeManager.dwm =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./dwm/home.nix ];
      modules.home.dwm.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
