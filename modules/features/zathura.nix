{
  flake.modules.homeManager.zathura =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./zathura/home.nix ];
      modules.home.zathura.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
