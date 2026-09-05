{
  moduleWithSystem,
  ...
}:
{
  flake.modules.homeManager.gondolin = moduleWithSystem (
    { config, ... }:
    { lib, pkgs, ... }:
    {
      imports = [ ./gondolin/home.nix ];

      modules.home.gondolin = {
        enable = lib.mkDefault true;
        package = lib.mkDefault config.packages.gondolin;
        binaryCache.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
      };
    }
  );

  perSystem =
    { pkgs, ... }:
    {
      packages.gondolin = pkgs.callPackage ./gondolin/package.pkg.nix { };
    };
}
