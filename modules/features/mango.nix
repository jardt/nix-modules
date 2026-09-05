{
  config,
  moduleWithSystem,
  ...
}:
let
  moduleFlake = config.nixModules.sourceFlake;

  mkMangoModule =
    {
      externalModule,
      implementation,
      optionPath,
    }:
    moduleWithSystem (
      { config, ... }:
      let
        perSystemConfig = config;
      in
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = lib.getAttrFromPath optionPath config;
      in
      {
        imports = [
          externalModule
          implementation
        ];

        config = lib.mkMerge [
          (lib.setAttrByPath (optionPath ++ [ "enable" ]) (lib.mkDefault pkgs.stdenv.hostPlatform.isLinux))
          (lib.mkIf cfg.enable (
            lib.setAttrByPath (optionPath ++ [ "package" ]) (lib.mkDefault perSystemConfig.packages.mango)
          ))
        ];
      }
    );
in
{
  flake.modules = {
    homeManager.mango = mkMangoModule {
      externalModule = moduleFlake.inputs.mango.hmModules.mango;
      implementation = ./mango/home.nix;
      optionPath = [
        "modules"
        "home"
        "mango"
      ];
    };

    nixos.mango = mkMangoModule {
      externalModule = moduleFlake.inputs.mango.nixosModules.mango;
      implementation = ./mango/nixos.nix;
      optionPath = [
        "modules"
        "nixos"
        "mango"
      ];
    };
  };

  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        mango =
          (pkgs.callPackage "${moduleFlake.inputs.mango}/nix" {
            scenefx = moduleFlake.inputs.mango.inputs.scenefx.packages.${system}.default;
          }).overrideAttrs
            (old: {
              buildInputs = old.buildInputs ++ [ pkgs.libdrm ];
              NIX_CFLAGS_COMPILE = "-I${pkgs.libdrm.dev}/include/libdrm";
            });
      };
    };
}
