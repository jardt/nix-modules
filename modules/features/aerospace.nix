{
  flake.modules.homeManager.aerospace =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./aerospace/home.nix ];
      modules.home.aerospace.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isDarwin;
    };
}
